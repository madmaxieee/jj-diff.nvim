local M = {}

---@param opts snacks.picker.git.diff.Config
---@type snacks.picker.finder
local function jj_diff_finder(opts, ctx)
  opts = opts or {}

  local jj = require("jj-diff")
  local cwd = jj.find_root(ctx:cwd())
  if not cwd then
    return function() end
  end
  ctx.picker:set_cwd(cwd)

  local Diff = require("snacks.picker.source.diff")
  ---@type snacks.picker.finder.result
  local finder = Diff.diff(
    ctx:opts({
      -- Keep picker transforms out of the raw diff parser.
      transform = false,
      cmd = "jj",
      -- stylua: ignore
      args = {
        "--no-pager", "--color=never",
        "--config", "ui.diff-formatter=:git",
        "diff", "--from", jj.config.base_rev,
      },
      cwd = cwd,
    }),
    ctx
  )

  return function(cb)
    local items = {} ---@type snacks.picker.finder.Item[]
    finder(function(item)
      item.staged = false
      items[#items + 1] = item
    end)
    table.sort(items, function(a, b)
      if a.file ~= b.file then
        return a.file < b.file
      end
      return a.pos[1] < b.pos[1]
    end)
    for _, item in ipairs(items) do
      cb(item)
    end
  end
end

---@param defaults snacks.picker.Config
---@param opts? snacks.picker.Config
local function pick(defaults, opts)
  local picker = require("snacks.picker")
  local config = vim.tbl_deep_extend("force", defaults, opts or {})
  config.finder = jj_diff_finder
  picker.pick(config)
end

---Open a Snacks picker for changes from the configured Jujutsu base revision.
---@param opts? snacks.picker.Config Extra picker options. `finder` is always Jujutsu's finder.
function M.diff(opts)
  pick({
    title = "Jujutsu Diff",
    format = "git_status",
    preview = "diff",
  }, opts)
end

---Open a Snacks status picker for files changed from the configured Jujutsu base revision.
---@param opts? snacks.picker.Config Extra picker options. `finder` is always Jujutsu's finder.
function M.status(opts)
  pick({
    title = "Jujutsu Status",
    format = "git_status",
    preview = "diff",
    -- imitate snacks' git_status behavior by grouping the diff hunks
    group = true,
  }, opts)
end

return M

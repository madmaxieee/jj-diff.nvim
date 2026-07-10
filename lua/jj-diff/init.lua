local M = {}

M.config = {
  base_rev = "@-",
}

---@type table<integer, { fs_event: uv.uv_fs_event_t, timer: uv.uv_timer_t, request: integer, revision: string }>
local cache = {}

local function jj_cmd(...)
  return vim.list_extend({ "jj", "--no-pager", "--color=never" }, { ... })
end

---@param entry { fs_event: uv.uv_fs_event_t, timer: uv.uv_timer_t }?
local function cleanup(entry)
  if not entry then
    return
  end
  entry.fs_event:stop()
  entry.fs_event:close()
  entry.timer:stop()
  entry.timer:close()
end

---@param path? integer|string buffer number or file path
---@return string?
function M.find_root(path)
  path = path or 0
  path = type(path) == "number" and vim.api.nvim_buf_get_name(path) or path
  path = path == "" and vim.uv.cwd() or vim.fs.normalize(path)

  if vim.uv.fs_stat(path .. "/.jj") then
    return path
  end

  for dir in vim.fs.parents(path) do
    if vim.uv.fs_stat(dir .. "/.jj") then
      return vim.fs.normalize(dir)
    end
  end
end

local function set_ref_text(buf, entry, request, revision, text)
  vim.schedule(function()
    if
      not vim.api.nvim_buf_is_valid(buf)
      or cache[buf] ~= entry
      or entry.request ~= request
      or entry.revision ~= revision
      or M.config.base_rev ~= revision
    then
      return
    end
    local ok, err = pcall(require("mini.diff").set_ref_text, buf, text)
    if not ok then
      vim.notify(err, vim.log.levels.WARN)
    end
  end)
end

local function get_ref_text(root, path, revision, callback)
  local relative_path = vim.fs.relpath(root, path)
  if not relative_path then
    callback(false)
    return
  end

  -- `jj file show` does not follow renames. Resolve the source path using a
  -- JSON string template so paths with whitespace remain unambiguous.
  local template =
    'stringify(if(self.status() == "renamed", self.source().path(), self.path())).escape_json() ++ "\\n"'
  vim.system(
    jj_cmd(
      "diff",
      "-f",
      revision,
      "-t",
      "@",
      "-T",
      template,
      "--",
      relative_path
    ),
    { cwd = root },
    function(diff)
      if diff.code ~= 0 then
        callback(false)
        return
      end

      local base_path = relative_path
      local output = vim.trim(diff.stdout or "")
      if output ~= "" then
        local ok, resolved = pcall(vim.json.decode, output)
        if not ok or type(resolved) ~= "string" or resolved == "" then
          callback(false)
          return
        end
        base_path = resolved
      end

      vim.system(
        jj_cmd(
          "--ignore-working-copy",
          "file",
          "show",
          "-r",
          revision,
          "--",
          base_path
        ),
        { cwd = root },
        function(res)
          if res.code == 0 then
            callback(true, res.stdout or "")
            return
          end

          -- Only a current file missing from the base is new. Invalid revisions
          -- and operational failures must not become an empty reference.
          vim.system(
            jj_cmd("file", "show", "-r", "@", "--", relative_path),
            { cwd = root },
            function(current)
              if current.code == 0 then
                callback(true, "")
              else
                callback(false)
              end
            end
          )
        end
      )
    end
  )
end

local function refresh_all()
  for buf, entry in pairs(cache) do
    entry.request = entry.request + 1
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        require("mini.diff").disable(buf)
        require("mini.diff").enable(buf)
      end
    end)
  end
end

---@return table mini.diff source
function M.source()
  if vim.fn.executable("jj") ~= 1 then
    return {
      name = "jj",
      attach = function()
        return false
      end,
      detach = function() end,
    }
  end

  -- When jj cannot provide a reference, decline this source on the immediate
  -- re-enable so mini.diff can try the next configured source.
  local unavailable = {}
  local source = {
    name = "jj",
    attach = function(buf)
      if unavailable[buf] then
        unavailable[buf] = nil
        return false
      end
      if cache[buf] then
        return false
      end

      local name = vim.api.nvim_buf_get_name(buf)
      if name == "" then
        return false
      end
      local path = vim.uv.fs_realpath(name) or vim.fs.normalize(name)
      local root = path and M.find_root(path)
      if not root then
        return false
      end

      local event, timer = vim.uv.new_fs_event(), vim.uv.new_timer()
      if not event or not timer then
        return false
      end
      local entry = {
        fs_event = event,
        timer = timer,
        request = 0,
        revision = M.config.base_rev,
      }
      cache[buf] = entry

      local function update()
        entry.request = entry.request + 1
        entry.revision = M.config.base_rev
        local request, revision = entry.request, entry.revision
        get_ref_text(root, path, revision, function(ok, text)
          if
            cache[buf] ~= entry
            or entry.request ~= request
            or entry.revision ~= revision
            or M.config.base_rev ~= revision
          then
            return
          end
          if ok then
            set_ref_text(buf, entry, request, revision, text)
            return
          end

          -- Do not retain a reference from an earlier successful request.
          -- Detaching and enabling makes mini.diff advance to the next source.
          entry.request = entry.request + 1
          unavailable[buf] = true
          vim.schedule(function()
            if cache[buf] == entry and vim.api.nvim_buf_is_valid(buf) then
              require("mini.diff").disable(buf)
              require("mini.diff").enable(buf)
            end
          end)
        end)
      end
      local function on_change(err, filename)
        if err or (filename and filename ~= "checkout") then
          return
        end
        timer:stop()
        timer:start(50, 0, update)
      end

      local ok = pcall(
        event.start,
        event,
        root .. "/.jj/working_copy",
        { recursive = false },
        on_change
      )
      if not ok then
        cleanup(cache[buf])
        cache[buf] = nil
        return false
      end
      timer:start(0, 0, update)
    end,
    detach = function(buf)
      cleanup(cache[buf])
      cache[buf] = nil
    end,
  }
  return source
end

---@param rev string
function M.set_base_rev(rev)
  M.config.base_rev = rev
  refresh_all()
end

---@param opts? { base_rev?: string }
function M.setup(opts)
  if opts and opts.base_rev ~= nil then
    M.config.base_rev = opts.base_rev
  end
end

return M

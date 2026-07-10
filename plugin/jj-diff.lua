vim.api.nvim_create_user_command("JJDiff", function(command)
  local path = vim.api.nvim_buf_get_name(0)
  vim.system({
    "jj",
    "--no-pager",
    "--color=never",
    "log",
    "-r",
    command.args,
    "--no-graph",
    "-T",
    "",
  }, { cwd = vim.fs.dirname(path) }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify(
          ("jj: '%s' is not a valid rev"):format(command.args),
          vim.log.levels.ERROR
        )
        return
      end
      local jj_diff = require("jj-diff")
      jj_diff.set_base_rev(command.args)
      vim.notify(("jj: reference rev is set to '%s'"):format(command.args))
    end)
  end)
end, { nargs = 1, force = true })

vim.api.nvim_create_user_command("JJDiffIncludeParent", function()
  local jj_diff = require("jj-diff")
  jj_diff.set_base_rev("@--")
  vim.notify(
    ("jj: reference rev is set to '%s'"):format(jj_diff.config.base_rev)
  )
end, { nargs = 0, force = true })

vim.api.nvim_create_user_command("JJDiffExcludeParent", function()
  local jj_diff = require("jj-diff")
  jj_diff.set_base_rev("@-")
  vim.notify(
    ("jj: reference rev is set to '%s'"):format(jj_diff.config.base_rev)
  )
end, { nargs = 0, force = true })

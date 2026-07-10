# jj-diff.nvim

Jujutsu (`jj`) source for [mini.diff](https://github.com/nvim-mini/mini.diff).
It shows a buffer's changes relative to a configurable jj revision and refreshes
when jj updates the working-copy checkout.

## Requirements

- Neovim 0.10 or newer
- [mini.diff](https://github.com/nvim-mini/mini.diff)
- [`jj`](https://github.com/jj-vcs/jj) available in `$PATH`

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "nvim-mini/mini.diff",
  dependencies = { "madmaxieee/jj-diff.nvim" },
  config = function()
    require("mini.diff").setup({
      source = {
        require("jj-diff").source(),
        require("mini.diff").gen_source.git(),
        require("mini.diff").gen_source.save(),
        require("mini.diff").gen_source.none(),
      },
    })
  end,
}
```

## Configuration

No setup call is needed when using the default base revision, `@-`. To use a
different revision, call `setup()` before configuring `mini.diff`:

```lua
require("jj-diff").setup({
  base_rev = "@-", -- revision used as the diff base
})
```

The plugin creates these commands:

- `:JJDiff {revision}`: set the reference revision and refresh attached buffers.
- `:JJDiffIncludeParent`: set the reference revision to `@--`.
- `:JJDiffExcludeParent`: set the reference revision to `@-`.

`require("jj-diff").source()` returns the source to place first in
`mini.diff`'s `source` list, so jj repositories take precedence over Git.

## Snacks picker integration

The optional Snacks integration is loaded separately, so Snacks is not required
for the base mini.diff source:

```lua
require("jj-diff.snacks").diff()

-- Show one entry per changed file.
require("jj-diff.snacks").status()

-- Pass any additional picker options.
require("jj-diff.snacks").diff({
  layout = "select",
  win = { input = { keys = { ["<C-j>"] = { "list_down", mode = { "i", "n" } } } } },
})
```

It opens a Jujutsu diff picker using the same `base_rev` and repository root as
the base plugin. Add [Snacks.nvim](https://github.com/folke/snacks.nvim) as a
dependency only when using this integration. Caller options override the default
title, format, preview, and status grouping; the Jujutsu finder is always used.

To use the Jujutsu picker in a jj repository and retain the usual Git status
picker elsewhere:

```lua
{
  "<leader>fg",
  function()
    if require("jj-diff").find_root() ~= nil then
      require("jj-diff.snacks").diff()
    else
      require("snacks").picker.git_status()
    end
  end,
  desc = "Git status",
}
```

## License

MIT. See [LICENSE](LICENSE).

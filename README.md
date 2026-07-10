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
  "your-name/jj-diff.nvim",
  dependencies = { "nvim-mini/mini.diff" },
  opts = {},
  config = function(_, opts)
    local jj = require("jj-diff")
    jj.setup(opts)

    require("mini.diff").setup({
      source = {
        jj.source(),
        require("mini.diff").gen_source.git(),
        require("mini.diff").gen_source.save(),
        require("mini.diff").gen_source.none(),
      },
    })
  end,
}
```

## Configuration

```lua
require("jj-diff").setup({
  base_rev = "@-", -- revision used as the diff base
})
```

The plugin creates these commands:

- `:JJDiff {revision}`: set the reference revision and refresh attached buffers.
- `:JJPDiff`: toggle the reference revision between `@-` and `@--`.

`require("jj-diff").source()` returns the source to place first in
`mini.diff`'s `source` list, so jj repositories take precedence over Git.

## Snacks picker integration

The optional Snacks integration is loaded separately, so Snacks is not required
for the base mini.diff source:

```lua
require("jj-diff.snacks").diff()
```

It opens a Jujutsu diff picker using the same `base_rev` and repository root as
the base plugin. Add [Snacks.nvim](https://github.com/folke/snacks.nvim) as a
dependency only when using this integration.

## License

MIT. See [LICENSE](LICENSE).

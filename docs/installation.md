# Installation

### With [Lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "WKDSteve/reposcope.nvim",
  name = "reposcope",
  dependencies = { "WKDSteve/lib.nvim", "WKDSteve/ui.nvim" },
  event = "VeryLazy",
  config = function()
    require("reposcope.init").setup({})
  end,
}
```

### With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "WKDSteve/reposcope.nvim",
  name = "reposcope",
  dependencies = { "WKDSteve/lib.nvim", "WKDSteve/ui.nvim" },
  event = "VeryLazy",
  config = function()
    require("reposcope.init").setup({})
  end,
}
```

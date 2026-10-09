---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      "lua",
      "vim",
      "json",
      "html",
      "markdown",
      "typescript",
      "tsx",
      "astro",
      "javascript",
      "go",
      "css", -- add more arguments for adding more treesitter parsers
    },
    auto_install = true,
    highlight = { enable = true },
    indent = { enable = true }, -- optional: experimentell
  },
}

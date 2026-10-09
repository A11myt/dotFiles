---@type LazySpec
return {
  "nvimtools/none-ls.nvim",
  opts = function(_, opts)
    local null_ls = require "null-ls"
    opts.sources = require("astrocore").list_insert_unique(opts.sources, {
      null_ls.builtins.formatting.prettier.with {
        extra_args = { "--print-width", "120" },
      },
      null_ls.builtins.formatting.stylua.with {
        extra_args = {
          "--indent-type", "Spaces",
          "--indent-width", "2",
          "--column-width", "120",
          "--quote-style", "AutoPreferDouble", -- optional
        },
      },
    })
  end,
}

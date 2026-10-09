-- JavaScript-spezifische Konfiguration
-- Wird automatisch geladen für .js, .jsx Dateien

-- Buffer-lokale Optionen für JavaScript

-- JavaScript-spezifische Keymaps
local opts = { buffer = true, silent = true }

-- Console.log shortcuts
vim.keymap.set(
  "n",
  "<leader>cl",
  "oconsole.log();<Esc>hi",
  vim.tbl_extend("force", opts, { desc = "Insert console.log" })
)
vim.keymap.set(
  "v",
  "<leader>cl",
  'c console.log(<C-r>");<Esc>',
  vim.tbl_extend("force", opts, { desc = "Wrap selection in console.log" })
)

-- Prettier formatting (via none-ls)
vim.keymap.set("n", "<leader>mp", function()
  vim.lsp.buf.format({ name = "null-ls" })
end, vim.tbl_extend("force", opts, { desc = "Format with Prettier" }))

-- React-spezifische Snippets erweitern (aus user.lua)
local luasnip = require("luasnip")
luasnip.filetype_extend("javascript", { "javascriptreact" })

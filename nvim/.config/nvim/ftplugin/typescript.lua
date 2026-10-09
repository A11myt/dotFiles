-- TypeScript-spezifische Konfiguration
-- Wird automatisch geladen für .ts, .tsx Dateien

-- Buffer-lokale Optionen für TypeScript

-- TypeScript-spezifische Keymaps
local opts = { buffer = true, silent = true }

-- TypeScript-spezifische LSP Aktionen
vim.keymap.set(
  "n",
  "<leader>to",
  ":TypescriptOrganizeImports<CR>",
  vim.tbl_extend("force", opts, { desc = "Organize Imports" })
)
vim.keymap.set("n", "<leader>tr", ":TypescriptRenameFile<CR>", vim.tbl_extend("force", opts, { desc = "Rename File" }))
vim.keymap.set(
  "n",
  "<leader>ti",
  ":TypescriptAddMissingImports<CR>",
  vim.tbl_extend("force", opts, { desc = "Add Missing Imports" })
)

-- Console.log shortcuts (wie JavaScript)
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

-- React-spezifische Snippets erweitern für .tsx
local luasnip = require("luasnip")
luasnip.filetype_extend("typescript", { "typescriptreact" })

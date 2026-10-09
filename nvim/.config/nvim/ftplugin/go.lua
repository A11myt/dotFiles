-- Go-spezifische Konfiguration
-- Wird automatisch geladen für .go Dateien

-- Buffer-lokale Optionen für Go
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4
vim.opt_local.expandtab = false
vim.opt_local.textwidth = 140
vim.opt_local.colorcolumn = "140"

-- Go-spezifische Keymaps
local opts = { buffer = true, silent = true }

-- Go-spezifische LSP Aktionen (gopls)
vim.keymap.set("n", "<leader>gi", function()
  vim.lsp.buf.code_action({
    filter = function(action)
      return action.kind == "source.organizeImports"
    end,
    apply = true,
  })
end, vim.tbl_extend("force", opts, { desc = "Organize Imports" }))

-- Go Build und Run
vim.keymap.set("n", "<leader>gb", ":!go build<CR>", vim.tbl_extend("force", opts, { desc = "Go Build" }))
vim.keymap.set("n", "<leader>gr", ":!go run %<CR>", vim.tbl_extend("force", opts, { desc = "Go Run current file" }))
vim.keymap.set("n", "<leader>gt", ":!go test<CR>", vim.tbl_extend("force", opts, { desc = "Go Test" }))

-- Go fmt on save (zusätzlich zu LSP formatting)
vim.api.nvim_create_autocmd("BufWritePre", {
  buffer = 0,
  desc = "Go fmt and organize imports on save",
  callback = function()
    vim.lsp.buf.format({ timeout_ms = 2000 })
    vim.lsp.buf.code_action({
      filter = function(action)
        return action.kind == "source.organizeImports"
      end,
      apply = true,
    })
  end,
})

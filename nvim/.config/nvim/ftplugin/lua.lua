local opts = { buffer = true, silent = true }

-- stylua: ignore start
vim.keymap.set("n", "<leader>lr", ":luafile %<CR>", vim.tbl_extend("force", opts, { desc = "Reload current lua file" }))
vim.keymap.set( "n", "<leader>lc", ":lua require('plenary.reload').reload_module(vim.fn.expand('%:t:r'))<CR>", vim.tbl_extend("force", opts, { desc = "Clear and reload module" }))

vim.keymap.set("n", "<leader>ls", function()
  vim.lsp.buf.format({
    filter = function(client)
      return client.name == "null-ls"
    end,
    timeout_ms = 2000,
  })
end, vim.tbl_extend("force", opts, { desc = "Format with Stylua" }))

vim.keymap.set( "n", "<leader>lp", "oprint(vim.inspect()))<Esc>hi", vim.tbl_extend("force", opts, { desc = "Insert print(vim.inspect())" }))
vim.keymap.set( "v", "<leader>lp", 'c print(vim.inspect(<C-r>"))<Esc>', vim.tbl_extend("force", opts, { desc = "Wrap selection in print(vim.inspect())" }))

if vim.fn.expand("%:p"):match(vim.fn.stdpath("config")) then
  vim.keymap.set( "n", "<leader>so", ":source %<CR>", vim.tbl_extend("force", opts, { desc = "Source current config file" }))
end
-- stylua: ignore end

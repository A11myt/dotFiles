-- Java-spezifische Konfiguration
-- Nutzt astrocommunity.pack.java aus community.lua
-- DAP, LSP, Testing bereits durch astrocommunity konfiguriert


-- Java-spezifische Keymaps (ergänzen die astrocommunity defaults)
local opts = { buffer = true, silent = true }

-- Zusätzliche Java-spezifische Shortcuts
vim.keymap.set("n", "<leader>jo", function()
  vim.lsp.buf.code_action({
    filter = function(action)
      return action.kind == "source.organizeImports"
    end,
    apply = true,
  })
end, vim.tbl_extend("force", opts, { desc = "Organize Java Imports" }))

-- Maven/Gradle shortcuts (falls verwendet)
vim.keymap.set("n", "<leader>jc", ":!mvn compile<CR>", vim.tbl_extend("force", opts, { desc = "Maven compile" }))
vim.keymap.set("n", "<leader>jt", ":!mvn test<CR>", vim.tbl_extend("force", opts, { desc = "Maven test" }))

-- Java-spezifische Autocmds (ergänzen astrocommunity)
vim.api.nvim_create_autocmd("BufWritePre", {
  buffer = 0,
  desc = "Auto-organize imports on save",
  callback = function()
    -- Nutzt jdtls von astrocommunity.pack.java
    pcall(function()
      vim.lsp.buf.code_action({
        filter = function(action)
          return action.kind == "source.organizeImports"
        end,
        apply = true,
      })
    end)
  end,
})

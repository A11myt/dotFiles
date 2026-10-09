-- Markdown-spezifische Konfiguration
-- Wird automatisch geladen für .md Dateien

-- Buffer-lokale Optionen für Markdown (aus polish.lua übernommen)
vim.opt_local.textwidth = 140
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2
vim.opt_local.expandtab = true
vim.opt_local.conceallevel = 2
vim.opt_local.spell = true
vim.opt_local.spelllang = "de,en"

-- Formatoptions für Markdown (aus polish.lua adaptiert)
local fo = table.concat(vim.opt_local.formatoptions:get(), "")
fo = fo:gsub("l", "") .. "t"
vim.opt_local.formatoptions = fo

-- Markdown-spezifische Keymaps
local opts = { buffer = true, silent = true }

-- Markdown Formatierung
vim.keymap.set("n", "<leader>mf", "gggqG<C-o><C-o>", vim.tbl_extend("force", opts, { desc = "Format entire markdown file" }))
vim.keymap.set("v", "<leader>mf", "gq", vim.tbl_extend("force", opts, { desc = "Format selected text" }))

-- Markdown Links
vim.keymap.set("v", "<leader>ml", 'c[<C-r>"]()<Esc>i', vim.tbl_extend("force", opts, { desc = "Create markdown link from selection" }))

-- Headlines.nvim Konfiguration (aus community.lua)
-- Wird durch das Plugin automatisch angewendet

-- Markdown Preview (falls du ein Preview Plugin hinzufügst)
vim.keymap.set("n", "<leader>mp", ":MarkdownPreviewToggle<CR>", vim.tbl_extend("force", opts, { desc = "Toggle Markdown Preview" }))

-- Table of Contents generieren (einfache Version)
vim.keymap.set("n", "<leader>mt", function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local toc = {}
  for i, line in ipairs(lines) do
    local level, title = line:match("^(#+)%s+(.+)$")
    if level then
      local indent = string.rep("  ", #level - 1)
      local link = title:lower():gsub("[^%w%s-]", ""):gsub("%s+", "-")
      table.insert(toc, indent .. "- [" .. title .. "](#" .. link .. ")")
    end
  end

  if #toc > 0 then
    vim.api.nvim_put(toc, "l", true, true)
  else
    print("No headings found")
  end
end, vim.tbl_extend("force", opts, { desc = "Generate Table of Contents" }))

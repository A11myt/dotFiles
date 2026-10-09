-- ~/.config/nvim/lua/config/keymaps.lua
local map = vim.keymap.set
local default_opts = { noremap = true, silent = true }

-- === Buffer Navigation ===
map("n", "]b", function() require("astrocore.buffer").nav(vim.v.count1) end, { desc = "Next buffer" })
map("n", "[b", function() require("astrocore.buffer").nav(-vim.v.count1) end, { desc = "Previous buffer" })

-- === Buffer schließen mit Picker ===
map("n", "<Leader>bd", function()
  require("astroui.status.heirline").buffer_picker(function(bufnr) require("astrocore.buffer").close(bufnr) end)
end, { desc = "Close buffer from tabline" })

-- === Allgemeine Navigation ===
map("n", "<leader>w", "<cmd>w<CR>", default_opts) -- speichern
map("n", "<leader>q", "<cmd>q<CR>", default_opts) -- schließen
map("n", "<leader>e", "<cmd>Neotree toggle<CR>", default_opts) -- Dateibaum umschalten

-- === Teleskope Shortcuts ===
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", default_opts)
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", default_opts)
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", default_opts)
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", default_opts)

-- === Fenster und Tabs ===
map("n", "<leader>sv", "<C-w>v", default_opts) -- split vertical
map("n", "<leader>sh", "<C-w>s", default_opts) -- split horizontal
map("n", "<leader>se", "<C-w>=", default_opts) -- gleiche Breite
map("n", "<leader>sx", "<cmd>close<CR>", default_opts)

-- === Sonstiges ===
map("n", "<leader>tt", "<cmd>ToggleTerm<CR>", { desc = "Terminal umschalten" })

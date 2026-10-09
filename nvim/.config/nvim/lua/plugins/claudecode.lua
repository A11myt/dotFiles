---@type LazySpec
return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  config = true,
  -- `cmd` lässt lazy.nvim Command-Stubs anlegen, damit `:ClaudeCode` etc. auch vor
  -- dem ersten Tastendruck existieren (sonst erst beim ersten <leader>a*-Mapping geladen)
  cmd = {
    "ClaudeCode",
    "ClaudeCodeFocus",
    "ClaudeCodeSelectModel",
    "ClaudeCodeAdd",
    "ClaudeCodeSend",
    "ClaudeCodeTreeAdd",
    "ClaudeCodeStatus",
    "ClaudeCodeStart",
    "ClaudeCodeStop",
    "ClaudeCodeOpen",
    "ClaudeCodeClose",
    "ClaudeCodeDiffAccept",
    "ClaudeCodeDiffDeny",
    "ClaudeCodeCloseAllDiffs",
  },
  keys = {
    { "<leader>a", nil, desc = "AI/Claude Code" },
    { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Claude Code umschalten" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude Code fokussieren" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Claude Code fortsetzen" },
    { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Claude Code weiterführen" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Claude-Modell wählen" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Aktuellen Buffer hinzufügen" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Auswahl an Claude senden" },
    {
      "<leader>as",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Datei hinzufügen",
      ft = { "neo-tree", "oil", "minifiles", "netrw", "snacks_picker_list" },
    },
    -- Diff-Verwaltung
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Diff annehmen" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Diff ablehnen" },
  },
}

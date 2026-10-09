-- Customize Mason

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        -- Language Servers
        "lua-language-server",
        "omnisharp",
        "jdtls", -- Java LSP (wird von astrocommunity.pack.java verwendet)
        "arduino-language-server",
        "astro-language-server",
        "bash-language-server",
        "eslint-lsp",
        "html-lsp",
        "json-lsp",
        "gopls",
        "mdx-analyzer",
        "svelte-language-server",
        "tailwindcss-language-server",
        "typescript-language-server",

        -- Formatters
        "prettier",
        "google-java-format", -- Java Formatter
        -- "stylua",
        -- "selene",

        -- Debugger / CLI Tools
        "firefox-debug-adapter",
        "java-debug-adapter", -- Java Debugger
        "java-test", -- Java Test Runner
        -- "tree-sitter-cli", -- Installiert über npm: npm install -g tree-sitter-cli
      },
      auto_update = true,
    },
  },
}

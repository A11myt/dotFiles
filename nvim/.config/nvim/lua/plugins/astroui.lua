-- AstroUI provides the basis for configuring the AstroNvim User Interface
-- Configuration documentation can be found with `:h astroui`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

local c = require "config.colors"

---@type LazySpec
return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  opts = {
    -- change colorscheme
    -- colorscheme = "tokyonight",
    -- colorscheme = "everforest",
    colorscheme = "nord",
    -- AstroUI allows you to easily modify highlight groups easily for any and all colorschemes

    highlights = {
      init = { -- this table overrides highlights in all themes
        -- Normal
        Normal = { bg = "none" },
        SignColumn = { bg = "none" },
        FoldColumn = { bg = "none" },
        NormalFloat = { bg = "none" },
        NormalNC = { bg = "none" },
        NormalSB = { bg = "none" },
        FloatBorder = { fg = c.outline, bg = "none" },
        FloatTitle = { fg = c.on_surface, bg = "none" },
        -- WinBar
        WinBar = { bg = "none" },
        WinSeparator = { fg = c.outline, bg = "none" },
        WinBarNC = { bg = "none" },
        WhichKeyFloat = { bg = "none" },
        -- Telescope
        TelescopeBorder = { fg = c.outline, bg = "none" },
        TelescopePromptTitle = { fg = c.primary, bg = "none" },
        TelescopePromptBorder = { fg = c.outline, bg = "none" },
        TelescopeNormal = { bg = "none" },
        -- Diagnosis
        DiagnosticVirtualTextHint = { fg = c.on_surface_variant, bg = "none" },
        DiagnosticVirtualTextWarn = { fg = c.tertiary, bg = "none" },
        DiagnosticVirtualTextInfo = { fg = c.secondary, bg = "none" },
        DiagnosticVirtualTextError = { fg = c.error, bg = "none" },
        -- NeoTree
        NeoTreeNormal = { bg = "none" },
        NeoTreeNormalNC = { bg = "none" },
        NeoTreeTabInactive = { bg = "none" },
        NeoTreeTabSeparatorActive = { fg = c.primary, bg = "none" },
        NeoTreeTabSapertorInactive = { fg = c.outline, bg = "none" },
        NvimTreeTabSaperatorActive = { fg = c.primary, bg = "none" },
        NvimTreeTabSeparatorInactive = { fg = c.outline, bg = "none" },
        MiniTabLineFill = { fg = c.on_surface, bg = "none" },
        -- Spectre
        DiffChange = { fg = c.on_primary_container, bg = c.primary_container },
        DiffDelete = { fg = c.on_error_container, bg = c.error_container },
        -- StatusLine
        StatusLine = { fg = c.on_surface, bg = "none" },
        StatusLineNC = { fg = c.on_surface_variant, bg = "none" },
        StatusLineTerm = { fg = c.on_surface, bg = "none" },
        StatusLineTermNC = { fg = c.on_surface_variant, bg = "none" },
        VertSplit = { fg = c.outline, bg = "none" },
        -- QuickFixLine
        QuickFixLine = { bg = "none" },
        -- TabLine
        TabLine = { bg = "none" },
        TabLineSel = { fg = c.primary, bg = "none" },
        TabLineFill = { bg = "none" },
        -- Cursor
        CursorLineNr = { fg = c.primary, bg = "none" },
        CursorLine = { bg = "none" },
        ColorColumn = { bg = "none" },
        -- Search
        Search = { fg = c.on_primary, bg = c.primary },
        IncSearch = { fg = c.on_primary, bg = c.secondary },
        -- Pmenu
        Pmenu = { bg = "none" },
        PmenuSel = { fg = c.on_primary, bg = c.primary_container },
        PmenuSbar = { bg = "none" },
        PmenuThumb = { bg = c.outline },
        -- Notifications
        NotifyINFOBody = { bg = "none" },
        NotifyWARNBody = { bg = "none" },
        NotifyERRORBody = { bg = "none" },
        NotifyDEBUGBody = { bg = "none" },
        NotifyTRACEBody = { bg = "none" },
        NotifyINFOBorder = { fg = c.secondary, bg = "none" },
        NotifyWARNBorder = { fg = c.tertiary, bg = "none" },
        NotifyERRORBorder = { fg = c.error, bg = "none" },
        NotifyDEBUGBorder = { fg = c.outline, bg = "none" },
        NotifyTRACEBorder = { fg = c.outline, bg = "none" },
        NotifyBackground = { bg = "none" },
      },
    },
    -- Icons can be configured throughout the interface
    icons = {
      -- configure the loading of the lsp in the status line
      LSPLoading1 = "⠋",
      LSPLoading2 = "⠙",
      LSPLoading3 = "⠹",
      LSPLoading4 = "⠸",
      LSPLoading5 = "⠼",
      LSPLoading6 = "⠴",
      LSPLoading7 = "⠦",
      LSPLoading8 = "⠧",
      LSPLoading9 = "⠇",
      LSPLoading10 = "⠏",
    },
  },
}

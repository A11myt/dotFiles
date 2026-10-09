local polish = function()
  require("config.keymaps")

  -- ===== LSP-ATTACH-FIX FÜR DIE ERSTE DATEI EINER SESSION =====
  -- mason-lspconfig lädt (per lazy.nvim) erst beim "User AstroFile"-Event, also
  -- genau beim Öffnen der ersten echten Datei. Dessen FileType-Autocmd wird dabei
  -- aber zu spät registriert, um noch für DIESEN Buffer zu feuern -> der LSP-Server
  -- (z.B. lua_ls) hängt sich nicht an und Dinge wie `grn` (Rename) tun scheinbar nichts.
  -- Fix: FileType-Event für den aktuellen Buffer einmalig neu auslösen, nachdem alle
  -- AstroFile-Handler (inkl. mason-lspconfig-Setup) durchgelaufen sind.
  vim.api.nvim_create_autocmd("User", {
    pattern = "AstroFile",
    once = true,
    callback = function()
      vim.schedule(function() vim.cmd.doautocmd("FileType " .. vim.bo.filetype) end)
    end,
    desc = "Re-trigger FileType so LSP attaches to the first file of a session",
  })

  -- Setze formatoptions: entferne "l", füge "t" hinzu
  local fo = table.concat(vim.opt.formatoptions:get(), "")
  -- fo = fo:gsub("l", "") .. "t"
  fo = fo:gsub("l", ""):gsub("t", "")
  vim.opt.formatoptions = fo
  vim.opt.textwidth = 140
  vim.opt.wrap = true
  vim.o.textwidth = 0
  -- Globalen rechten Ruler auf Spalte 120 setzen
  -- vim.opt.colorcolumn = "120"
  -- vim.opt.formatprg = ""

  vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function()
      -- vim.cmd("normal! ggVGgq")
    end,
  })

  -- ===== MATUGEN LIVE-RELOAD =====
  -- Wendet matugen-Farben nach jedem ColorScheme-Wechsel und bei FocusGained an.
  -- Läuft nach AstroUI und überschreibt dessen gecachte Startup-Farben.
  local function apply_matugen_hl()
    package.loaded["config.matugen_colors"] = nil
    package.loaded["config.colors"] = nil
    local c = require "config.colors"

    -- vim.schedule stellt sicher, dass wir NACH AstroUI laufen
    vim.schedule(function()
    local hl = function(group, opts) vim.api.nvim_set_hl(0, group, opts) end

    hl("FloatBorder",                { fg = c.outline,              bg = "none" })
    hl("FloatTitle",                 { fg = c.on_surface,           bg = "none" })
    hl("WinSeparator",               { fg = c.outline,              bg = "none" })
    hl("VertSplit",                  { fg = c.outline,              bg = "none" })
    hl("TelescopeBorder",            { fg = c.outline,              bg = "none" })
    hl("TelescopePromptTitle",       { fg = c.primary,              bg = "none" })
    hl("TelescopePromptBorder",      { fg = c.outline,              bg = "none" })
    hl("DiagnosticVirtualTextHint",  { fg = c.on_surface_variant,   bg = "none" })
    hl("DiagnosticVirtualTextWarn",  { fg = c.tertiary,             bg = "none" })
    hl("DiagnosticVirtualTextInfo",  { fg = c.secondary,            bg = "none" })
    hl("DiagnosticVirtualTextError", { fg = c.error,                bg = "none" })
    hl("DiagnosticError",            { fg = c.on_surface_variant })
    hl("DiagnosticWarn",             { fg = c.on_surface_variant })
    hl("DiagnosticInfo",             { fg = c.on_surface_variant })
    hl("DiagnosticHint",             { fg = c.on_surface_variant })
    hl("LspReferenceText",           { fg = c.on_surface_variant })
    hl("LspReferenceRead",           { fg = c.on_surface_variant })
    hl("LspReferenceWrite",          { fg = c.on_surface_variant })
    hl("NeoTreeTabSeparatorActive",  { fg = c.primary,              bg = "none" })
    hl("NeoTreeTabSapertorInactive", { fg = c.outline,              bg = "none" })
    hl("DiffChange",                 { fg = c.on_primary_container, bg = c.primary_container })
    hl("DiffDelete",                 { fg = c.on_error_container,   bg = c.error_container })
    hl("StatusLine",                 { fg = c.on_surface,           bg = "none" })
    hl("StatusLineNC",               { fg = c.on_surface_variant,   bg = "none" })
    hl("CursorLineNr",               { fg = c.primary,              bg = "none" })
    hl("TabLineSel",                 { fg = c.primary,              bg = "none" })
    hl("Search",                     { fg = c.on_primary,           bg = c.primary })
    hl("IncSearch",                  { fg = c.on_primary,           bg = c.secondary })
    hl("PmenuSel",                   { fg = c.on_primary,           bg = c.primary_container })
    hl("PmenuThumb",                 { bg = c.outline })
    hl("NotifyINFOBorder",           { fg = c.secondary,            bg = "none" })
    hl("NotifyWARNBorder",           { fg = c.tertiary,             bg = "none" })
    hl("NotifyERRORBorder",          { fg = c.error,                bg = "none" })
    hl("MiniTabLineFill",            { fg = c.on_surface,           bg = "none" })

    -- Syntax: nur 2 Akzente
    hl("@function",                  { fg = c.primary })
    hl("@function.method",           { fg = c.primary })
    hl("@string",                    { fg = c.secondary })
    end) -- end vim.schedule
  end

  -- Läuft nach AstroUI's ColorScheme-Handler und überschreibt gecachte Farben
  vim.api.nvim_create_autocmd({ "ColorScheme", "FocusGained" }, {
    callback = apply_matugen_hl,
    desc = "Matugen-Farben anwenden",
  })

  -- Einmalig beim Start
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = apply_matugen_hl,
    desc = "Matugen-Farben initial anwenden",
  })

  -- Benutzerbefehl für manuellen Reload
  vim.api.nvim_create_user_command("MatugenReload", function()
    apply_matugen_hl()
    vim.notify("Matugen-Farben neu geladen", vim.log.levels.INFO)
  end, { desc = "Matugen-Farben manuell neu laden" })
end

polish()

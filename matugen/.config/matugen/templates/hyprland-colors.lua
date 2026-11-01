-- Generated with Matugen – wird von layout.lua per require("themes.matugen") geladen
local M = {}

M.image = "{{image}}"

<* for name, value in colors *>
M.{{name}} = "rgba({{value.default.hex_stripped}}ff)"
<* endfor *>

return M

-- Arbeitsflächen folgen den Monitoren:
--   1 → Laptop (eDP-1), 2/3 → erster/zweiter externer Monitor von links nach rechts.
-- Die Namen externer Monitore wechseln je nach Dock/Port (DP-3, DP-4, HDMI-A-2 …),
-- deshalb zählt nur die Position. Ohne externe Monitore landet alles auf dem Laptop.
-- Läuft beim Start, beim Einstecken und beim Abziehen.

local INTERNAL    = "eDP-1"
local EXTERNAL_WS = { 2, 3 }

local function externals()
    local list = {}
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= INTERNAL then
            table.insert(list, m)
        end
    end
    table.sort(list, function(a, b) return a.x < b.x end)
    return list
end

local function workspace_exists(id)
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id == id then
            return true
        end
    end
    return false
end

local function distribute()
    local ext = externals()
    local before = hl.get_active_workspace()
    for i, id in ipairs(EXTERNAL_WS) do
        local mon = ext[i]
        local target = mon and mon.name or INTERNAL
        -- Regel: wird die Arbeitsfläche neu angelegt (SUPER+2), dann gleich auf dem richtigen Monitor
        hl.workspace_rule({ workspace = tostring(id), monitor = target, default = mon ~= nil })
        if workspace_exists(id) then
            -- mitsamt Fenstern rüberschieben
            hl.dispatch(hl.dsp.workspace.move({ workspace = id, monitor = target }))
        end
        if mon then
            -- auf dem externen Monitor anzeigen (legt sie bei Bedarf an); sonst zeigte ein frisch
            -- eingesteckter Monitor eine neue leere Nummer (4, 5 …) statt 2/3
            hl.dispatch(hl.dsp.focus({ monitor = target }))
            hl.dispatch(hl.dsp.focus({ workspace = id }))
        end
    end
    -- Fokus dorthin zurück, wo er vorher war
    if before then
        hl.dispatch(hl.dsp.focus({ workspace = before.id }))
    end
end

hl.workspace_rule({ workspace = "1", monitor = INTERNAL, default = true })

-- Bei jedem Laden der Config (Reload passiert bei jedem Farbwechsel) nur die Regeln setzen –
-- ohne Fenster zu schieben oder den Fokus anzufassen. Beim allerersten Laden gibt es noch
-- keine Monitore, dann übernimmt hyprland.start.
pcall(function()
    local ext = externals()
    for i, id in ipairs(EXTERNAL_WS) do
        hl.workspace_rule({ workspace = tostring(id), monitor = ext[i] and ext[i].name or INTERNAL,
                            default = ext[i] ~= nil })
    end
end)

hl.on("hyprland.start", distribute)
hl.on("monitor.added", distribute)
hl.on("monitor.removed", distribute)

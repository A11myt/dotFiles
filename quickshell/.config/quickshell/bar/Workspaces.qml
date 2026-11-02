import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components

// Nummer + bis zu 3 einfarbige App-Symbole (Nerd Font, sonst eingefärbtes Icon);
// 1–5 immer sichtbar, belegte darüber kommen dazu
Pill {
    id: root
    padX: 6
    readonly property var base: [1, 2, 3, 4, 5]
    readonly property int maxIcons: 3

    // Arbeitsfläche → Fensterklassen (ohne Duplikate, ohne Scratchpads)
    readonly property var occupied: {
        const m = {}
        for (const t of Hyprland.toplevels.values) {
            const id = t.workspace?.id ?? 0
            const cls = t.lastIpcObject?.class ?? ""
            if (id < 1 || !cls) continue
            if (!m[id]) m[id] = []
            if (!m[id].includes(cls)) m[id].push(cls)
        }
        return m
    }
    readonly property var ids: [...new Set([...base, ...Object.keys(occupied).map(Number)])].sort((a, b) => a - b)

    // einfarbige Symbole für bekannte Programme (Fensterklasse klein geschrieben)
    readonly property var glyphs: ({
        "firefox": "󰈹", "firefox-esr": "󰈹", "librewolf": "󰈹", "zen": "󰈹",
        "chromium": "", "google-chrome": "", "brave-browser": "",
        "alacritty": "", "kitty": "", "foot": "", "org.wezfurlong.wezterm": "", "dropdown": "", "xterm": "",
        "org.gnome.nautilus": "󰉋", "thunar": "󰉋", "nemo": "󰉋",
        "code": "󰨞", "code-oss": "󰨞", "vscodium": "󰨞", "dev.zed.zed": "󰨞",
        "obsidian": "󰠮", "md.obsidian.obsidian": "󰠮",
        "discord": "󰙯", "vesktop": "󰙯", "spotify": "󰓇", "steam": "󰓓",
        "thunderbird": "󰇰", "org.telegram.desktop": "", "signal": "󰭹",
        "vlc": "󰕼", "mpv": "󰐌", "gimp": "", "org.inkscape.inkscape": "", "godot": "", "blender": "󰂫",
        "org.pulseaudio.pavucontrol": "󰕾", "blueman-manager": "󰂯", "satty": "󰏫",
        "org.gnome.papers": "󰈦", "org.gnome.evince": "󰈦", "zathura": "󰈦", "ristretto": "󰋩", "org.gnome.loupe": "󰋩",
        "floating-term": ""
    })
    function glyphFor(cls) {
        const c = cls.toLowerCase()
        return glyphs[c] ?? (c.startsWith("libreoffice") ? "󰏆" : c.startsWith("steam_app") ? "󰊴" : "")
    }

    function iconFor(cls) {
        const e = DesktopEntries.heuristicLookup(cls)
        return Quickshell.iconPath(e?.icon ?? cls.toLowerCase(), "application-x-executable")
    }
    function focus(target) {
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${typeof target === "number" ? target : '"' + target + '"'} })`])
    }

    onScrolled: e => focus(e.angleDelta.y > 0 ? "e-1" : "e+1")

    Repeater {
        model: root.ids
        delegate: Rectangle {
            id: ws
            required property int modelData
            readonly property bool active: Hyprland.focusedWorkspace?.id === modelData
            readonly property var classes: root.occupied[modelData] ?? []
            readonly property bool wsHovered: wsMouse.containsMouse

            implicitWidth: wsRow.implicitWidth + 20
            implicitHeight: 22
            radius: 14
            color: active ? Qt.alpha(Theme.primary, wsHovered ? 0.88 : 0.75)
                          : (wsHovered ? Qt.alpha(Theme.surfaceVariant, 0.12) : Qt.alpha(Theme.surfaceVariant, 0.05))
            Behavior on color { ColorAnimation { duration: Theme.anim } }
            Behavior on implicitWidth { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: ws.modelData
                    anchors.verticalCenter: parent.verticalCenter
                    color: ws.active ? Theme.fgOnPrimary : (ws.wsHovered ? Theme.primary : Theme.fgMuted)
                    opacity: (ws.classes.length || ws.active) ? 1 : 0.45
                    font.family: ws.active ? Theme.fontAccent : Theme.fontUi
                    font.pixelSize: Theme.fontPx
                    font.letterSpacing: ws.active ? 2 : 0
                }
                Repeater {
                    model: ws.classes.slice(0, root.maxIcons)
                    delegate: Item {
                        id: app
                        required property string modelData
                        readonly property string glyph: root.glyphFor(modelData)
                        readonly property color tint: ws.active ? Theme.fgOnPrimary : (ws.wsHovered ? Theme.primary : Theme.fgMuted)
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: glyph ? glyphText.implicitWidth : 15
                        implicitHeight: 15
                        Text {
                            id: glyphText
                            visible: app.glyph !== ""
                            anchors.centerIn: parent
                            text: app.glyph
                            color: app.tint
                            font.family: Theme.fontUi
                            font.pixelSize: 15
                            Behavior on color { ColorAnimation { duration: Theme.anim } }
                        }
                        // unbekannte Programme: echtes Icon, einfarbig eingefärbt
                        IconImage {
                            id: icon
                            visible: false
                            anchors.fill: parent
                            source: app.glyph ? "" : root.iconFor(app.modelData)
                        }
                        MultiEffect {
                            visible: app.glyph === ""
                            anchors.fill: parent
                            source: icon
                            colorization: 1.0
                            colorizationColor: app.tint
                            brightness: 0.15
                        }
                    }
                }
                Text {
                    visible: ws.classes.length > root.maxIcons
                    text: "+" + (ws.classes.length - root.maxIcons)
                    anchors.verticalCenter: parent.verticalCenter
                    color: ws.active ? Theme.fgOnPrimary : Theme.fgMuted
                    font.pixelSize: 10
                }
            }
            MouseArea { id: wsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.focus(ws.modelData) }
            Tooltip { target: ws; show: ws.wsHovered; text: ws.classes.length ? ws.classes.join(", ") : "leer" }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Belegte Arbeitsflächen: ein App-Icon pro Fenster (Nummer optional, Einstellungen → Leiste),
// leere: Nummer. 1–5 immer sichtbar, belegte darüber kommen dazu
Pill {
    id: root
    padX: 6
    readonly property var base: [1, 2, 3, 4, 5]
    readonly property int maxIcons: 4
    readonly property bool numbers: Config.bar.wsNumbers === true

    // Arbeitsfläche → Fensterklassen, eine pro Fenster (ohne Scratchpads), nach Klasse gruppiert
    readonly property var occupied: {
        const m = {}
        for (const t of Hyprland.toplevels.values) {
            const id = t.workspace?.id ?? 0
            const cls = t.lastIpcObject?.class ?? ""
            if (id < 1 || !cls) continue
            if (!m[id]) m[id] = []
            m[id].push(cls)
        }
        for (const k in m) m[k].sort()
        return m
    }
    function summary(classes) {
        const n = {}
        for (const c of classes) n[c] = (n[c] ?? 0) + 1
        return Object.entries(n).map(([c, k]) => k > 1 ? `${c} ×${k}` : c).join(", ")
    }
    readonly property var ids: [...new Set([...base, ...Object.keys(occupied).map(Number)])].sort((a, b) => a - b)

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

            implicitWidth: wsRow.implicitWidth + (ws.classes.length ? 14 : 20)
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
                    visible: ws.classes.length === 0 || root.numbers
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
                    delegate: IconImage {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 17
                        source: root.iconFor(modelData)
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
            Tooltip { target: ws; show: ws.wsHovered; text: `Arbeitsfläche ${ws.modelData}: ` + (ws.classes.length ? root.summary(ws.classes) : "leer") }
        }
    }
}

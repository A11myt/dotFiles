import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs

// Fensterübersicht (SUPER+Tab): alle Arbeitsflächen als Kacheln mit Live-Vorschau der Fenster.
// Klick auf Fenster = dorthin springen, Klick auf Kachel = Arbeitsfläche wechseln,
// Fenster ziehen = auf andere Arbeitsfläche verschieben, Esc schließt, 1–9 springen.
PanelWindow {
    id: win
    property bool open: false
    readonly property var mon: Hyprland.focusedMonitor
    screen: Quickshell.screens.find(s => s.name === mon?.name) ?? Quickshell.screens[0]

    visible: open || closing.running
    onOpenChanged: if (!open) closing.restart(); else grid.forceActiveFocus()
    Timer { id: closing; interval: Theme.anim }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    IpcHandler {
        target: "overview"
        function toggle(): void { win.open = !win.open }
    }

    function dispatch(lua) { Quickshell.execDetached(["hyprctl", "dispatch", lua]) }
    function gotoWs(id) { dispatch(`hl.dsp.focus({ workspace = ${id} })`); open = false }
    function focusWindow(t) { dispatch(`hl.dsp.focus({ window = "address:0x${t.address}" })`); open = false }
    function moveWindow(t, id) { dispatch(`hl.dsp.window.move({ workspace = ${id}, window = "address:0x${t.address}", silent = true })`) }

    // Arbeitsflächen: 1–5 immer, belegte darüber dazu (ohne Scratchpads)
    readonly property var windows: Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? 0) > 0)
    readonly property var ids: [...new Set([1, 2, 3, 4, 5, ...windows.map(t => t.workspace.id)])].sort((a, b) => a - b)
    readonly property int cols: ids.length <= 6 ? 3 : 4
    readonly property real tileW: Math.min((width * 0.88 - (cols - 1) * 24) / cols, 520)
    readonly property real tileH: tileW * (mon ? mon.height / mon.width : 9 / 16)

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.scrim, 0.5)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        MouseArea { anchors.fill: parent; onClicked: win.open = false }
    }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: win.cols
        rowSpacing: 24
        columnSpacing: 24
        focus: true
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { win.open = false; e.accepted = true }
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) { win.gotoWs(e.key - Qt.Key_0); e.accepted = true }
        }

        Repeater {
            model: win.ids
            delegate: Rectangle {
                id: tile
                required property int modelData
                readonly property int wsId: modelData
                readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                readonly property var wsMon: ws?.monitor ?? win.mon
                readonly property real sc: win.tileW / Math.max(1, wsMon?.width ?? 1920)
                readonly property bool active: Hyprland.focusedWorkspace?.id === wsId

                Layout.preferredWidth: win.tileW
                Layout.preferredHeight: win.tileH + 26
                color: "transparent"

                Rectangle {
                    id: screenArea
                    width: win.tileW
                    height: win.tileH
                    radius: 12
                    clip: true
                    color: Qt.alpha(Theme.surfaceContainer, 0.85)
                    border.width: drop.containsDrag ? 3 : (tile.active ? 2 : 1)
                    border.color: drop.containsDrag || tile.active ? Theme.primary : Theme.outlineVariant

                    MouseArea { anchors.fill: parent; onClicked: win.gotoWs(tile.wsId) }

                    DropArea {
                        id: drop
                        anchors.fill: parent
                        keys: ["qs-window"]
                        onDropped: d => { if (d.source?.toplevel && d.source.wsId !== tile.wsId) win.moveWindow(d.source.toplevel, tile.wsId) }
                    }

                    Repeater {
                        model: win.windows.filter(t => t.workspace.id === tile.wsId)
                        delegate: Item {
                            id: preview
                            required property var modelData
                            readonly property var toplevel: modelData
                            readonly property int wsId: tile.wsId
                            readonly property var ipc: modelData.lastIpcObject
                            readonly property real homeX: ((ipc?.at?.[0] ?? 0) - (tile.wsMon?.x ?? 0)) * tile.sc
                            readonly property real homeY: ((ipc?.at?.[1] ?? 0) - (tile.wsMon?.y ?? 0)) * tile.sc
                            x: homeX
                            y: homeY
                            width: (ipc?.size?.[0] ?? 100) * tile.sc
                            height: (ipc?.size?.[1] ?? 100) * tile.sc
                            z: dragArea.drag.active ? 10 : (ipc?.floating ? 2 : 1)

                            Drag.active: dragArea.drag.active
                            Drag.keys: ["qs-window"]
                            Drag.source: preview
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 6
                                color: Theme.surfaceContainerHigh
                                border.width: dragArea.containsMouse ? 2 : 0
                                border.color: Theme.primary
                                ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: win.open ? preview.toplevel.wayland : null
                                    live: true
                                }
                                IconImage {   // App-Icon unten links als Erkennungszeichen
                                    anchors { left: parent.left; bottom: parent.bottom; margins: 4 }
                                    implicitSize: Math.min(28, parent.height / 3)
                                    source: Quickshell.iconPath(DesktopEntries.heuristicLookup(preview.ipc?.class ?? "")?.icon ?? "", "application-x-executable")
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                drag.target: preview
                                property bool moved: false
                                onPressed: moved = false
                                onPositionChanged: if (drag.active) moved = true
                                onReleased: {
                                    if (moved) {
                                        preview.Drag.drop()
                                        // zurück an den Platz; ein Verschieben aktualisiert Hyprland ohnehin
                                        preview.x = Qt.binding(() => preview.homeX)
                                        preview.y = Qt.binding(() => preview.homeY)
                                    } else {
                                        win.focusWindow(preview.toplevel)
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors { top: screenArea.bottom; topMargin: 6; horizontalCenter: screenArea.horizontalCenter }
                    text: tile.wsId + (tile.wsMon && tile.wsMon !== win.mon ? "  ·  " + tile.wsMon.name : "")
                    color: tile.active ? Theme.primary : Theme.fgMuted
                    font.family: Theme.fontAccent
                    font.pixelSize: 14
                }
            }
        }
    }
}

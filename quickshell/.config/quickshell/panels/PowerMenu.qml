import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Power-Menü (CTRL+ALT+ENTF): Sperren L, Abmelden E, Ruhezustand U, Neustart R, Ausschalten S.
// Esc oder Klick daneben schließt. Vor Abmelden/Neustart/Aus wird der Sitzungsstand gemerkt.
PanelWindow {
    id: win
    visible: Power.open || closing.running
    onVisibleChanged: if (visible) frame.forceActiveFocus()
    Timer { id: closing; interval: Theme.anim }
    Connections { target: Power; function onOpenChanged() { if (!Power.open) closing.restart() } }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-power"
    WlrLayershell.keyboardFocus: Power.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    readonly property var actions: [
        { key: "l", icon: "󰌾", label: "Sperren",     cmd: "loginctl lock-session", danger: false },
        { key: "e", icon: "󰍃", label: "Abmelden",    cmd: "~/.local/bin/session save; loginctl terminate-user $USER", danger: false },
        { key: "u", icon: "󰤄", label: "Ruhezustand", cmd: "systemctl suspend", danger: false },
        { key: "r", icon: "󰜉", label: "Neustart",    cmd: "~/.local/bin/session save; systemctl reboot", danger: true },
        { key: "s", icon: "󰐥", label: "Ausschalten", cmd: "~/.local/bin/session save; systemctl poweroff", danger: true }
    ]
    function run(a) {
        Power.open = false
        // kurz warten, bis das Menü weg ist (sonst landet es z. B. im Sperrbildschirm-Screenshot)
        Quickshell.execDetached(["bash", "-c", "sleep 0.2; " + a.cmd])
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        color: Qt.alpha(Theme.scrim, 0.55)
        opacity: Power.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { Power.open = false; return }
            const a = win.actions.find(x => x.key === e.text.toLowerCase())
            if (a) win.run(a)
        }
        MouseArea { anchors.fill: parent; onClicked: Power.open = false }

        RowLayout {
            anchors.centerIn: parent
            spacing: 18
            scale: Power.open ? 1 : 0.92
            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
            Repeater {
                model: win.actions
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool hot: btn.containsMouse
                    implicitWidth: 130; implicitHeight: 150
                    radius: 18
                    color: hot ? (modelData.danger ? Theme.error : Theme.primary) : Qt.alpha(Theme.surfaceContainerHigh, 0.95)
                    border.width: 1
                    border.color: hot ? color : Theme.outlineVariant
                    Behavior on color { ColorAnimation { duration: 150 } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData.icon; font.pixelSize: 40; font.family: Theme.fontUi
                               color: parent.parent.hot ? (modelData.danger ? Theme.fgOnError : Theme.fgOnPrimary) : Theme.primary }
                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData.label; font.pixelSize: 14; font.family: Theme.fontUi
                               color: parent.parent.hot ? (modelData.danger ? Theme.fgOnError : Theme.fgOnPrimary) : Theme.fg }
                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData.key.toUpperCase(); font.pixelSize: 12; font.family: Theme.fontAccent
                               color: parent.parent.hot ? (modelData.danger ? Theme.fgOnError : Theme.fgOnPrimary) : Theme.fgMuted }
                    }
                    MouseArea { id: btn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.run(modelData) }
                }
            }
        }
    }
}

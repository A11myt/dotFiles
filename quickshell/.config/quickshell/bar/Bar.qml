import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Leiste pro Monitor: links Launcher/Uhr/Wetter/Arbeitsflächen, Mitte Glocke/Medien, rechts Status
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // QS_BAR_BOTTOM=1 → unten (zum Testen parallel zur AGS-Leiste)
    readonly property bool bottom: Quickshell.env("QS_BAR_BOTTOM") === "1"
    anchors { top: !bottom; bottom: bottom; left: true; right: true }
    implicitHeight: 40
    color: Qt.alpha("#0f0f0f", 0.2)
    WlrLayershell.namespace: "qs-bar"

    Row {
        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 12
        Launcher {}
        Clock {}
        Weather {}
        Workspaces {}
    }
    Row {
        anchors.centerIn: parent
        spacing: 12
        Bell {}
        Media {}
    }
    Row {
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 12
        Updates {}
        Volume {}
        Battery {}
        Network {}
        PowerProfile {}
        QuickToggle {}
    }
}

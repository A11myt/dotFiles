import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Leiste pro Monitor: links Launcher/Uhr/Wetter/Arbeitsflächen, Mitte Glocke/Medien, rechts Status.
// Ausblendbare Elemente: Einstellungen → Leiste (Config.bar)
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // QS_BAR_BOTTOM=1 → unten (zum Testen neben einer laufenden Leiste)
    readonly property bool bottom: Quickshell.env("QS_BAR_BOTTOM") === "1"
    anchors { top: !bottom; bottom: bottom; left: true; right: true }
    implicitHeight: 40
    // dunkel: wie bisher fast durchsichtig; hell: helle Fläche, sonst ist die dunkle Schrift unlesbar
    color: Theme.isLight ? Qt.alpha(Theme.surface, 0.72) : Qt.alpha("#0f0f0f", 0.2)
    WlrLayershell.namespace: "qs-bar"

    Row {
        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 12
        Launcher {}
        Clock {}
        Weather { barKey: "weather" }
        Workspaces {}
    }
    Row {
        anchors.centerIn: parent
        spacing: 12
        Bell {}
        Media { barKey: "media" }
    }
    Row {
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 12
        RecordingPill {}
        FocusPill { barKey: "focus" }
        MailPill { barKey: "mail" }
        Tray { barKey: "tray" }
        Updates { barKey: "updates" }
        Privacy { barKey: "privacy" }
        Volume { barKey: "volume" }
        BluetoothPill { barKey: "bluetooth" }
        Battery { barKey: "battery" }
        Network { barKey: "network" }
        PowerProfile { barKey: "powerProfile" }
        QuickToggle {}
    }
}

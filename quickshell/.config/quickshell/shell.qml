import QtQuick
import Quickshell

// Phase-0-Test: kleine Leiste unten mit Theme-Farben und -Schrift
ShellRoot {
    PanelWindow {
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 34
        color: Theme.surfaceContainer

        Text {
            anchors.centerIn: parent
            text: "Quickshell-Test · primary " + Theme.primary + " · " + Theme.fontUi
            color: Theme.primary
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontPx
        }
    }
}

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Kopf einer Quick-Settings-Unterseite: ← zurück, Titel, optional Schalter und Aktivität
RowLayout {
    id: h
    property string title
    property bool hasToggle: true
    property bool checked: false
    property bool busy: false               // dreht ein Symbol (z. B. Suche läuft)
    signal toggled(bool on)
    Layout.fillWidth: true
    spacing: 8

    Rectangle {
        implicitWidth: 32; implicitHeight: 32; radius: 10
        color: back.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        Text { anchors.centerIn: parent; text: "󰁍"; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 16 }
        MouseArea { id: back; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Panels.page = "main" }
    }
    Text { text: h.title; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx + 3; font.bold: true; Layout.fillWidth: true }
    Text {
        visible: h.busy
        text: "󰑓"; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 15
        RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: h.busy }
    }
    Toggle { visible: h.hasToggle; checked: h.checked; onToggled: on => h.toggled(on) }
}

import QtQuick
import QtQuick.Layouts
import qs

// kleiner Knopf in aufgeklappten Zeilen; primary = Akzentfarbe, danger = Fehlerfarbe
Rectangle {
    id: b
    property string text
    property bool primary: false
    property bool danger: false
    property bool enabled: true
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 32
    implicitWidth: label.implicitWidth + 24
    radius: 10
    opacity: enabled ? 1 : 0.5
    color: primary ? (m.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
         : danger ? (m.containsMouse ? Theme.errorContainer : Qt.alpha(Theme.error, 0.15))
         : (m.containsMouse ? Theme.surfaceContainer : Theme.surfaceContainerLow)
    Text { id: label; anchors.centerIn: parent; text: b.text; color: b.primary ? Theme.fgOnPrimary : b.danger ? Theme.error : Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12 }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (b.enabled) b.clicked() }
}

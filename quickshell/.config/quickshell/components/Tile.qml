import QtQuick
import QtQuick.Layouts
import qs

// Kachel für Quick Settings: Symbol, Titel, Untertitel; an = Akzentfarbe
Rectangle {
    id: t
    property string icon
    property string title
    property string sub
    property bool on: false
    property bool detail: false            // Pfeil rechts → Unterseite (auch Rechtsklick)
    signal clicked()
    signal rightClicked()
    signal detailClicked()

    Layout.fillWidth: true
    implicitHeight: 56
    radius: 14
    color: on ? (mouse.containsMouse ? Qt.lighter(Theme.primary, 1.08) : Theme.primary)
              : (mouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 10
        Text { text: t.icon; font.pixelSize: 20; font.family: Theme.fontUi; color: t.on ? Theme.fgOnPrimary : Theme.fgMuted }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Text { text: t.title; font.bold: true; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; color: t.on ? Theme.fgOnPrimary : Theme.fg }
            Text { text: t.sub; font.family: Theme.fontUi; font.pixelSize: 11; color: t.on ? Theme.fgOnPrimary : Theme.fgMuted; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        Item { visible: t.detail; Layout.preferredWidth: 22; Layout.fillHeight: true }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => e.button === Qt.RightButton ? (t.detail ? t.detailClicked() : t.rightClicked()) : t.clicked()
    }
    // eigener Klickbereich für den Pfeil, mit Trennlinie
    Rectangle {
        visible: t.detail
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 38
        radius: t.radius
        color: arrow.containsMouse ? Qt.alpha(t.on ? Theme.fgOnPrimary : Theme.fg, 0.12) : "transparent"
        Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: 1; height: parent.height - 24; color: Qt.alpha(t.on ? Theme.fgOnPrimary : Theme.fg, 0.25) }
        Text { anchors.centerIn: parent; text: "󰅂"; font.pixelSize: 18; font.family: Theme.fontUi; color: t.on ? Theme.fgOnPrimary : Theme.fgMuted }
        MouseArea { id: arrow; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.detailClicked() }
    }
}

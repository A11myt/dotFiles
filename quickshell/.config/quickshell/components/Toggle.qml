import QtQuick
import qs

// Schalter in Theme-Farben (statt des grauen Qt-Standards)
Rectangle {
    id: t
    property bool checked: false
    signal toggled(bool checked)
    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.primary : Theme.surfaceContainerHighest
    border.width: checked ? 0 : 1
    border.color: Theme.outline
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: t.checked ? 16 : 12
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: t.checked ? t.width - width - 3 : 5
        color: t.checked ? Theme.fgOnPrimary : Theme.outline
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 150 } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled(!t.checked) }
}

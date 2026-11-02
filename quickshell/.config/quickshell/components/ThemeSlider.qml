import QtQuick
import qs

// Schieberegler in Theme-Farben; `moved(v)` beim Ziehen/Klicken (v = 0..1)
Item {
    id: s
    property real value: 0
    property real minimum: 0
    signal moved(real v)
    implicitHeight: 22
    implicitWidth: 200

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 8; radius: 4
        color: Theme.surfaceContainerHighest
        Rectangle {
            width: Math.max(height, parent.width * Math.min(1, s.value)); height: parent.height; radius: 4
            color: Theme.primary
        }
    }
    Rectangle {
        width: 16; height: 16; radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: (s.width - width) * Math.min(1, s.value)
        color: Theme.fg
        scale: drag.pressed ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function apply(x) { s.moved(Math.max(s.minimum, Math.min(1, x / width))) }
        onPressed: e => apply(e.x)
        onPositionChanged: e => { if (pressed) apply(e.x) }
        onWheel: e => s.moved(Math.max(s.minimum, Math.min(1, s.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}

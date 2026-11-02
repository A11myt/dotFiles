import QtQuick
import qs
import Quickshell

// Tooltip unter einem Element der Leiste; erscheint nach kurzer Verzögerung beim Hovern
PopupWindow {
    id: tip
    required property Item target
    property bool show: false
    property string text: ""

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6
    color: "transparent"
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 14
    visible: false

    Timer { id: delay; interval: 450; onTriggered: tip.visible = tip.show && tip.text !== "" }
    onShowChanged: show ? delay.restart() : (delay.stop(), tip.visible = false)

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.surface
        border.color: Theme.outline
        border.width: 1
        Text {
            id: label
            anchors.centerIn: parent
            text: tip.text
            color: Theme.fg
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontPx - 1
        }
    }
}

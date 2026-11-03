import QtQuick
import qs
import qs.services

// Balken-Visualizer (Daten von Cava); meldet sich nur an, solange er sichtbar ist
Item {
    id: vis
    property color color: Theme.primary
    property real gap: 3
    property bool mirror: false          // Balken zur Mitte hin spiegeln (sieht ruhiger aus)
    readonly property bool shownNow: visible && width > 0
    property bool counted: false
    onShownNowChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) Cava.users -= 1
    function sync() {
        if (shownNow && !counted) { Cava.users += 1; counted = true }
        else if (!shownNow && counted) { Cava.users -= 1; counted = false }
    }
    implicitHeight: 40

    Row {
        anchors.fill: parent
        spacing: vis.gap
        Repeater {
            model: Cava.bars
            delegate: Item {
                required property int index
                width: (vis.width - vis.gap * (Cava.bars - 1)) / Cava.bars
                height: vis.height
                readonly property int src: vis.mirror ? Math.abs(index - (Cava.bars - 1) / 2) * 2 | 0 : index
                // Wurzelkurve: kleine Ausschläge sichtbarer (Sprache, leise Stellen)
                readonly property real v: Math.pow(Cava.values[Math.min(src, Cava.bars - 1)] ?? 0, 0.6)
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, parent.height * parent.v)
                    radius: Math.min(width / 2, 3)
                    color: vis.color
                    opacity: 0.35 + 0.65 * parent.v
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }
    }
}

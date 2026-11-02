import QtQuick
import qs

// Text in Leisten-Optik: Theme-Schrift/-Farbe, Hover-Akzent über `accent`
Text {
    property bool accent: false
    color: accent ? Theme.primary : Theme.fg
    font.family: Theme.fontUi
    font.pixelSize: Theme.fontPx
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: 200 } }
}

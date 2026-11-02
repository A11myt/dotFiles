import QtQuick
import Quickshell
import qs
import qs.components

Pill {
    padX: 12
    onClicked: Quickshell.execDetached(["rofi", "-show", "drun"])
    BarText { text: "󰣇"; font.pixelSize: 18; accent: parent.parent.hovered }
}

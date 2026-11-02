import QtQuick
import qs
import qs.components
import qs.services

Pill {
    id: p
    onClicked: Panels.toggle("quick")
    BarText { text: "󰒓"; font.pixelSize: 16; accent: p.hovered || Panels.open === "quick" }
}

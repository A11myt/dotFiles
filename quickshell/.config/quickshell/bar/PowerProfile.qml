import QtQuick
import Quickshell.Services.UPower
import qs
import qs.components

Pill {
    id: p
    readonly property var order: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    readonly property var icons: ["󰌪", "󰗑", ""]
    readonly property var names: ["Sparsam", "Ausgewogen", "Leistung"]
    readonly property int idx: Math.max(0, order.indexOf(PowerProfiles.profile))
    onClicked: PowerProfiles.profile = order[(idx + 1) % order.length]
    BarText { text: p.icons[p.idx]; font.pixelSize: 16; accent: p.hovered }
    Tooltip { target: p; show: p.hovered; text: "Energieprofil: " + p.names[p.idx] }
}

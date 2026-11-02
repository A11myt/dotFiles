import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.components

Pill {
    id: p
    readonly property var dev: UPower.displayDevice
    readonly property real pct: dev?.percentage ?? 0
    readonly property bool charging: !UPower.onBattery
    readonly property bool critical: pct < 0.2 && !charging
    visible: dev?.isPresent ?? false
    color: critical ? Qt.alpha(Theme.error, 0.25) : (hovered ? hoverColor : Qt.alpha(Theme.surfaceVariant, 0.05))
    onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c", "akku; echo; upower -i $(upower -e | grep -m1 BAT) | less"])
    BarText {
        readonly property var icons: ["", "", "", "", ""]
        text: `${Math.round(p.pct * 100)}% ${p.charging ? "󱐋" : icons[Math.min(Math.floor(p.pct * 5), 4)]}`
        color: p.critical ? Theme.error : (p.hovered ? Theme.primary : Theme.fg)
    }
    Tooltip {
        target: p; show: p.hovered
        text: `Akku ${Math.round(p.pct * 100)} % – ${p.charging ? "am Netzteil" : "entlädt"}` +
              (p.dev?.timeToEmpty > 0 && !p.charging ? `\nnoch ca. ${Math.round(p.dev.timeToEmpty / 60)} min` : "")
    }
}

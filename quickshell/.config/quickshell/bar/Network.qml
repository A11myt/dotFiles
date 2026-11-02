import QtQuick
import Quickshell
import Quickshell.Networking
import qs
import qs.components

Pill {
    id: p
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var net: wifiDev?.networks?.values.find(n => n.connected) ?? null
    readonly property real strength: net?.signalStrength ?? 0
    onClicked: Quickshell.execDetached(["alacritty", "-e", "nmtui"])
    BarText {
        text: p.net ? `${p.strength > 0.75 ? "󰤨" : p.strength > 0.5 ? "󰤥" : p.strength > 0.25 ? "󰤢" : "󰤟"} ${p.net.name}` : "󰤮"
        accent: p.hovered
    }
    Tooltip { target: p; show: p.hovered; text: p.net ? `${p.net.name} – ${Math.round(p.strength * 100)} %` : "Kein WLAN" }
}

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.components
import qs.services

// Nur sichtbar, wenn ein Bluetooth-Gerät verbunden ist: Symbol + Akku. Klick → Bluetooth-Seite
Pill {
    id: p
    readonly property var devs: (Bluetooth.devices?.values ?? []).filter(d => d.connected)
    readonly property var dev: devs.find(d => d.batteryAvailable) ?? devs[0] ?? null
    visible: dev !== null
    onClicked: Panels.showPage("bluetooth")
    function icon(d) {
        const i = d?.icon ?? ""
        return i.includes("headset") || i.includes("headphone") || i.includes("audio") ? "󰋋" : i.includes("mouse") ? "󰍽" : i.includes("keyboard") ? "󰌌" : "󰂱"
    }
    BarText {
        readonly property int bat: Math.round((p.dev?.battery ?? 0) * 100)
        text: p.icon(p.dev) + (p.dev?.batteryAvailable ? ` ${bat}%` : "") + (p.devs.length > 1 ? ` +${p.devs.length - 1}` : "")
        accent: p.hovered
        color: p.dev?.batteryAvailable && bat <= 15 ? Theme.error : (accent ? Theme.primary : Theme.fg)
    }
    Tooltip { target: p; show: p.hovered; text: p.devs.map(d => d.name + (d.batteryAvailable ? ` – ${Math.round(d.battery * 100)} %` : "")).join("\n") }
}

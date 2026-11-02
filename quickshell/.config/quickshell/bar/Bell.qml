import QtQuick
import qs
import qs.components
import qs.services

// Glocke: Zustand aus dem Benachrichtigungsdienst, Klick öffnet die Zentrale
Pill {
    id: p
    readonly property bool has: Notifs.all.length > 0
    onClicked: Panels.toggle("center")
    BarText {
        text: Notifs.dnd ? (p.has ? "󰂠" : "󰪓") : (p.has ? "󱅫" : "󰂜")
        font.pixelSize: 16
        accent: p.hovered || Panels.open === "center"
    }
    Tooltip { target: p; show: p.hovered; text: p.has ? `${Notifs.all.length} Benachrichtigungen` : "Keine Benachrichtigungen" }
}

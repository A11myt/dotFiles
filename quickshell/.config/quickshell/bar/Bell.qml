import QtQuick
import qs
import qs.components
import qs.services

// Zustand kommt in Phase 2 aus dem Benachrichtigungsdienst (Notifs)
Pill {
    id: p
    onClicked: Panels.toggle("center")
    BarText { text: "󰂜"; font.pixelSize: 16; accent: p.hovered || Panels.open === "center" }
}

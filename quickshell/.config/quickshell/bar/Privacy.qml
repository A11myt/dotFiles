import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

// Warnpunkt, solange eine App das Mikrofon benutzt (Aufnahme-Stream in PipeWire)
Pill {
    id: p
    readonly property var recorders: Pipewire.nodes.values.filter(n => n.isStream && n.type === PwNodeType.AudioInStream)
    PwObjectTracker { objects: p.recorders }
    readonly property var names: [...new Set(recorders.map(n => n.properties?.["application.name"] || n.description || n.name).filter(Boolean))]
    visible: recorders.length > 0
    onClicked: Panels.showPage("audio")
    BarText { text: "󰍬"; color: Theme.error }
    Tooltip { target: p; show: p.hovered; text: "Mikrofon in Benutzung: " + p.names.join(", ") }
}

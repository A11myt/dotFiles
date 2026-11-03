import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.components

// Infobereich (StatusNotifier): Symbole von Apps wie Discord, Steam, Nextcloud.
// Klick = öffnen, Rechtsklick = Menü der App, Mittelklick = Zweitaktion, Scrollen = an die App
Pill {
    id: p
    padX: 8
    want: SystemTray.items.values.length > 0
    Repeater {
        model: SystemTray.items
        delegate: Item {
            id: it
            required property var modelData
            readonly property var item: modelData
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter
            IconImage {
                anchors.fill: parent
                source: it.item.icon
                opacity: it.item.status === Status.Passive ? 0.5 : 1
            }
            Rectangle {   // „braucht Aufmerksamkeit“
                visible: it.item.status === Status.NeedsAttention
                anchors { right: parent.right; top: parent.top }
                width: 6; height: 6; radius: 3; color: Theme.error
            }
            MouseArea {
                id: m
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: e => {
                    if (e.button === Qt.MiddleButton) it.item.secondaryActivate()
                    else if (e.button === Qt.RightButton || it.item.onlyMenu) menu.open()
                    else it.item.activate()
                }
                onWheel: e => it.item.scroll(e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x, e.angleDelta.y === 0)
            }
            QsMenuAnchor {
                id: menu
                menu: it.item.menu
                anchor.item: it
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
            Tooltip { target: it; show: m.containsMouse; text: it.item.tooltipTitle || it.item.title || it.item.id }
        }
    }
}

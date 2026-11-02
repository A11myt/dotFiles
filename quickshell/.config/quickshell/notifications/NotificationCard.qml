import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services

// Karte für Popup und Zentrale: App, Zeit, Titel, Text, Bild, Aktionen, Schließen.
// Klick auf die Karte = Standardaktion der App (falls vorhanden).
Rectangle {
    id: card
    required property var notif
    property bool popup: false
    readonly property bool critical: Notifs.isCritical(notif)
    readonly property var actions: (notif?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property var defaultAction: (notif?.actions ?? []).find(a => a.identifier === "default")
    readonly property date arrived: new Date()

    width: 360
    implicitHeight: col.implicitHeight + 20
    radius: 12
    color: popup ? Qt.alpha(Theme.surfaceContainerHigh, 0.97) : Theme.surfaceContainerHigh
    border.width: 1
    border.color: critical ? Theme.error : Theme.outlineVariant

    MouseArea {
        anchors.fill: parent
        cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            card.defaultAction?.invoke()
            if (card.popup) Notifs.dropPopup(card.notif)
        }
    }

    RowLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; leftMargin: 12; rightMargin: 12 }
        spacing: 10

        // Bild der Benachrichtigung oder App-Icon
        IconImage {
            readonly property string src: card.notif?.image || (card.notif?.appIcon ? Quickshell.iconPath(card.notif.appIcon, true) : "")
            visible: src !== ""
            source: src
            implicitSize: 36
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: card.notif?.appName || "Benachrichtigung"
                    color: Theme.primary
                    font.family: Theme.fontUi; font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: Qt.formatTime(card.arrived, "hh:mm")
                    color: Theme.fgMuted
                    font.family: Theme.fontUi; font.pixelSize: 11
                }
                Rectangle {
                    implicitWidth: 20; implicitHeight: 20; radius: 6
                    color: closeMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; color: closeMouse.containsMouse ? Theme.error : Theme.fgMuted; font.pixelSize: 11 }
                    MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: card.notif.dismiss() }
                }
            }
            Text {
                text: card.notif?.summary ?? ""
                color: Theme.fg
                font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; font.bold: true
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Text {
                visible: text !== ""
                text: card.notif?.body ?? ""
                textFormat: Text.StyledText
                color: Theme.fgMuted
                font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 3 : 8
                elide: Text.ElideRight
                Layout.fillWidth: true
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            RowLayout {
                visible: card.actions.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                Repeater {
                    model: card.actions
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: 8
                        color: actMouse.containsMouse ? Theme.primary : Theme.surfaceContainerHighest
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.text
                            color: actMouse.containsMouse ? Theme.fgOnPrimary : Theme.fg
                            font.family: Theme.fontUi; font.pixelSize: 12
                        }
                        MouseArea { id: actMouse; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.invoke() }
                    }
                }
            }
        }
    }
}

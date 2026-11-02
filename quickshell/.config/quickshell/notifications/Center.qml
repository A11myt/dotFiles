import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components

// Benachrichtigungszentrale rechts (Glocke, SUPER+A): Verlauf, Nicht stören, Alle löschen, Esc schließt
PanelWindow {
    id: win
    readonly property bool shown: Panels.open === "center"
    // beim Schließen kurz sichtbar lassen, damit das Hinausfahren zu sehen ist
    visible: shown || closing.running
    onShownChanged: if (!shown) closing.restart()
    Timer { id: closing; interval: Theme.anim + 60 }
    anchors { top: true; right: true; bottom: true }
    margins { top: 6; right: 10; bottom: 10 }
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notification-center"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: 400

    Rectangle {
        id: panel
        width: parent.width
        height: parent.height
        // fährt von rechts herein/hinaus (Verschiebung statt x → keine Bindungsschleife mit der Sichtbarkeit)
        transform: Translate {
            x: win.shown ? 0 : panel.width + 20
            Behavior on x { NumberAnimation { duration: Theme.anim + 40; easing.type: Easing.OutCubic } }
        }
        radius: 16
        color: Qt.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Theme.outlineVariant
        focus: win.shown
        Keys.onEscapePressed: Panels.close()

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Benachrichtigungen"
                    color: Theme.fg
                    font.family: Theme.fontAccent; font.pixelSize: 15
                    Layout.fillWidth: true
                }
                Text { text: "Nicht stören"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12 }
                Toggle {
                    checked: Notifs.dnd
                    onToggled: c => Notifs.dnd = c
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: ScriptModel { values: [...Notifs.all].reverse() }   // neueste oben
                delegate: NotificationCard {
                    required property var modelData
                    notif: modelData
                    width: list.width
                }
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.anim } }
                remove: Transition { NumberAnimation { property: "x"; to: 420; duration: Theme.anim; easing.type: Easing.InCubic } }
                displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.anim; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "Keine Benachrichtigungen"
                    color: Theme.fgMuted
                    font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                }
            }

            Rectangle {
                visible: list.count > 0
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 10
                color: clearMouse.containsMouse ? Theme.primary : Theme.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: "Alle löschen"
                    color: clearMouse.containsMouse ? Theme.fgOnPrimary : Theme.fg
                    font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                }
                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Notifs.dismissAll() }
            }
        }
    }
}

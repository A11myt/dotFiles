import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Popups oben rechts (fokussierter Monitor): gleiten herein, die übrigen rücken sanft nach
PanelWindow {
    id: win
    visible: Notifs.popups.length > 0
    anchors { top: true; right: true }
    margins { top: 6; right: 10 }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notifications"
    color: "transparent"
    implicitWidth: 370
    implicitHeight: Math.max(1, list.contentHeight + 10)

    ListView {
        id: list
        anchors.fill: parent
        spacing: 8
        interactive: false
        model: ScriptModel { values: Notifs.popups }   // vergleicht Listen → nur Neues wird animiert
        delegate: NotificationCard {
            required property var modelData
            notif: modelData
            popup: true
        }
        add: Transition {
            NumberAnimation { property: "x"; from: 380; to: 0; duration: Theme.anim + 60; easing.type: Easing.OutCubic }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.anim }
        }
        displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.anim; easing.type: Easing.OutCubic } }
    }
}

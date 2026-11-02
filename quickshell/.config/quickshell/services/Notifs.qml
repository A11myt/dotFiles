pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Benachrichtigungsdienst (org.freedesktop.Notifications):
// alle Benachrichtigungen für die Zentrale, frische zusätzlich als Popups.
Singleton {
    id: root

    readonly property int popupMs: 5000
    readonly property int maxPopups: 4
    readonly property var all: server.trackedNotifications.values
    property var popups: []          // Notification-Objekte, neueste zuerst
    property bool dnd: false

    function dismissAll() { for (const n of [...all]) n.dismiss() }
    function dropPopup(n) { popups = popups.filter(p => p !== n) }
    function isCritical(n) { return n.urgency === NotificationUrgency.Critical }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true                                  // bleibt in der Zentrale, bis geschlossen
            if (root.dnd && !root.isCritical(n)) return
            root.popups = [n, ...root.popups.filter(p => p !== n)].slice(0, root.maxPopups)
            if (!root.isCritical(n)) {
                const ms = n.expireTimeout > 0 ? n.expireTimeout * 1000 : root.popupMs
                Qt.callLater(() => hide.createObject(root, { target: n, interval: ms }))
            }
            n.closed.connect(() => root.dropPopup(n))
        }
    }

    // ein Timer pro Popup, der es nach Ablauf aus den Popups nimmt (bleibt in der Zentrale)
    Component {
        id: hide
        Timer {
            property var target
            running: true
            onTriggered: { root.dropPopup(target); destroy() }
        }
    }

    // „Nicht stören“ überlebt Neustarts
    FileView {
        id: dndFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/dnd"
        printErrors: false
        onLoaded: root.dnd = text().trim() === "1"
    }
    onDndChanged: Quickshell.execDetached(["bash", "-c", `mkdir -p ~/.cache/quickshell && echo ${dnd ? 1 : 0} > ~/.cache/quickshell/dnd`])
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.services

// WLAN-Unterseite: Netze in Reichweite, verbinden (mit Passwort), trennen, vergessen.
// Gesucht wird nur, solange die Seite offen ist.
ColumnLayout {
    id: page
    property bool active: false
    readonly property var dev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    property string expanded: ""          // Name der aufgeklappten Zeile
    property var errors: ({})              // Name → Fehlertext
    property bool showAll: false           // „Weitere Netze“ aufgeklappt

    spacing: 8

    Binding { target: page.dev; property: "scannerEnabled"; value: true; when: page.active && page.dev !== null && Networking.wifiEnabled }
    onActiveChanged: if (!active) { expanded = ""; showAll = false }

    readonly property var networks: (dev?.networks?.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    // kompakt: verbunden + gespeichert + die 3 stärksten fremden (nicht ganz schwach)
    readonly property var mine: networks.filter(n => n.connected || n.known)
    readonly property var others: networks.filter(n => !n.connected && !n.known)
    readonly property var topOthers: others.filter(n => n.signalStrength >= 0.25).slice(0, 3)
    readonly property var shown: showAll ? networks : mine.concat(topOthers)
    readonly property int hiddenCount: networks.length - mine.length - topOthers.length

    function strengthIcon(s) { return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : "󰤟" }
    function setError(name, msg) { const e = Object.assign({}, errors); if (msg) e[name] = msg; else delete e[name]; errors = e }
    function failText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets: return "Passwort fehlt oder ist falsch"
        case ConnectionFailReason.WifiAuthTimeout: return "Anmeldung abgelaufen – Passwort falsch?"
        case ConnectionFailReason.WifiNetworkLost: return "Netz nicht mehr erreichbar"
        default: return "Verbindung fehlgeschlagen"
        }
    }

    PageHeader {
        title: "WLAN"
        checked: Networking.wifiEnabled
        busy: page.active && Networking.wifiEnabled && (page.dev?.scannerEnabled ?? false) && page.networks.length === 0
        onToggled: on => Networking.wifiEnabled = on
    }

    Text {
        visible: !Networking.wifiEnabled
        Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 12
        horizontalAlignment: Text.AlignHCenter
        text: Networking.wifiHardwareEnabled ? "WLAN ist aus" : "WLAN ist per Schalter/Flugmodus gesperrt"
        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
    }

    Flickable {
        visible: Networking.wifiEnabled
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 380)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6

            Repeater {
                model: page.shown
                delegate: ListRow {
                    id: row
                    required property var modelData
                    readonly property var net: modelData
                    readonly property bool secured: net.security !== WifiSecurityType.Open
                    readonly property bool needsPassword: secured && !net.known
                    readonly property string err: page.errors[net.name] ?? ""

                    icon: net.stateChanging ? "󰑓" : page.strengthIcon(net.signalStrength)
                    busy: net.stateChanging
                    title: net.name
                    active: net.connected
                    expanded: page.expanded === net.name
                    trailing: secured ? "󰌾" : ""
                    sub: err ? err
                       : net.stateChanging ? (net.connected ? "Trenne …" : "Verbinde …")
                       : net.connected ? "Verbunden"
                       : net.known ? "Gespeichert"
                       : (secured ? WifiSecurityType.toString(net.security) : "Offen")
                    subColor: err ? Theme.error : (net.connected ? Theme.primary : Theme.fgMuted)

                    Connections {
                        target: row.net
                        function onConnectionFailed(reason) { page.setError(row.net.name, page.failText(reason)); if (row.secured) page.expanded = row.net.name }
                        function onConnectedChanged() { if (row.net.connected) { page.setError(row.net.name, ""); if (page.expanded === row.net.name) page.expanded = "" } }
                    }

                    onClicked: {
                        if (net.connected || net.known) { page.expanded = expanded ? "" : net.name; return }
                        if (needsPassword) { page.expanded = expanded ? "" : net.name; return }
                        page.setError(net.name, "")
                        net.connect()
                    }

                    // Passwort für unbekannte, gesicherte Netze
                    Rectangle {
                        visible: row.needsPassword || row.err !== ""
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 10
                        color: Theme.surfaceContainerLow
                        border.width: 1
                        border.color: pw.activeFocus ? Theme.primary : Theme.outlineVariant
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                            TextInput {
                                id: pw
                                Layout.fillWidth: true
                                echoMode: showPw.on ? TextInput.Normal : TextInput.Password
                                color: Theme.fg
                                font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                                clip: true
                                onAccepted: connectBtn.clicked()
                                Text { visible: !pw.text; text: "Passwort"; color: Theme.fgMuted; font: pw.font }
                            }
                            Text {
                                id: showPw
                                property bool on: false
                                text: on ? "󰈈" : "󰈉"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 15
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showPw.on = !showPw.on }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        ActionButton {
                            id: connectBtn
                            visible: !row.net.connected
                            primary: true
                            text: "Verbinden"
                            enabled: !row.net.stateChanging && (!row.needsPassword || pw.text.length >= 8)
                            onClicked: {
                                page.setError(row.net.name, "")
                                if (pw.visible && pw.text) row.net.connectWithPsk(pw.text)
                                else row.net.connect()
                                pw.text = ""
                            }
                        }
                        ActionButton { visible: row.net.connected; text: "Trennen"; onClicked: row.net.disconnect() }
                        ActionButton { visible: row.net.known; danger: true; text: "Vergessen"; onClicked: { row.net.forget(); page.expanded = "" } }
                    }
                    onExpandedChanged: if (expanded && needsPassword) pw.forceActiveFocus()
                }
            }

            // Rest auf-/zuklappen
            Rectangle {
                visible: page.hiddenCount > 0 || page.showAll
                Layout.fillWidth: true
                implicitHeight: 32; radius: 10
                color: moreM.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: page.showAll ? "󰅃  Weniger anzeigen" : `󰅀  Weitere Netze (${page.hiddenCount})`
                    color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12
                }
                MouseArea { id: moreM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.showAll = !page.showAll }
            }

            Text {
                visible: page.networks.length === 0
                Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 8
                horizontalAlignment: Text.AlignHCenter
                text: "Suche Netze …"
                color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
            }
        }
    }

    ActionButton {
        text: "󰒓  Erweiterte Netzwerkeinstellungen"
        onClicked: { Panels.close(); Quickshell.execDetached(["alacritty", "-e", "nmtui"]) }
    }
}

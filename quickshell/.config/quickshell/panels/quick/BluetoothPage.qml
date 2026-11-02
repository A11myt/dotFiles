import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services

// Bluetooth-Unterseite: gekoppelte Geräte (verbinden/trennen/vergessen, Akku) und
// neue Geräte in der Nähe (koppeln). Die Suche läuft nur, solange die Seite offen ist.
ColumnLayout {
    id: page
    property bool active: false
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool on: bt?.enabled ?? false
    property string expanded: ""

    spacing: 8

    Binding { target: page.bt; property: "discovering"; value: true; when: page.active && page.on }
    onActiveChanged: if (!active) expanded = ""

    readonly property var devices: (bt?.devices?.values ?? []).filter(d => d.name || d.deviceName)
    readonly property var paired: devices.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // unbenannte Geräte (nur Adresse) sind meist Werbe-Baken → ausblenden
    readonly property var nearby: devices.filter(d => !d.paired && !d.bonded && d.name && d.name.replace(/[-:]/g, "") !== d.address.replace(/[-:]/g, ""))

    function deviceIcon(icon) {
        const i = icon ?? ""
        return i.includes("headset") || i.includes("headphone") ? "󰋋"
             : i.includes("audio") ? "󰓃"
             : i.includes("keyboard") ? "󰌌"
             : i.includes("mouse") ? "󰍽"
             : i.includes("phone") ? "󰏲"
             : i.includes("computer") ? "󰟀"
             : i.includes("gaming") || i.includes("joystick") ? "󰊴"
             : "󰂯"
    }
    function stateText(d) {
        switch (d.state) {
        case BluetoothDeviceState.Connecting: return "Verbinde …"
        case BluetoothDeviceState.Disconnecting: return "Trenne …"
        case BluetoothDeviceState.Connected: return "Verbunden" + (d.batteryAvailable ? `  ·  󰁹 ${Math.round(d.battery * 100)} %` : "")
        default: return d.pairing ? "Kopple …" : (d.paired || d.bonded) ? "Gekoppelt" : "Neu"
        }
    }
    function busy(d) { return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting }

    PageHeader {
        title: "Bluetooth"
        checked: page.on
        busy: page.bt?.discovering ?? false
        onToggled: on => { if (page.bt) page.bt.enabled = on }
    }

    Text {
        visible: !page.on
        Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 12
        horizontalAlignment: Text.AlignHCenter
        text: !page.bt ? "Kein Bluetooth-Adapter gefunden" : page.bt.state === BluetoothAdapterState.Blocked ? "Bluetooth ist gesperrt (rfkill)" : "Bluetooth ist aus"
        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
    }

    Flickable {
        visible: page.on
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 400)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6

            SectionLabel { text: "Meine Geräte"; visible: page.paired.length > 0 }
            Repeater {
                model: page.paired
                delegate: ListRow {
                    id: row
                    required property var modelData
                    readonly property var dev: modelData
                    icon: page.busy(dev) ? "󰑓" : page.deviceIcon(dev.icon)
                    busy: page.busy(dev)
                    title: dev.name
                    sub: page.stateText(dev)
                    subColor: dev.connected ? Theme.primary : Theme.fgMuted
                    active: dev.connected
                    expanded: page.expanded === dev.address
                    // Klick klappt Verbinden/Trennen/Vergessen auf
                    trailing: expanded ? "󰅀" : "󰅂"
                    onClicked: page.expanded = expanded ? "" : dev.address

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        ActionButton {
                            primary: !row.dev.connected
                            text: row.dev.connected ? "Trennen" : "Verbinden"
                            enabled: !page.busy(row.dev)
                            onClicked: row.dev.connected ? row.dev.disconnect() : row.dev.connect()
                        }
                        ActionButton { danger: true; text: "Vergessen"; onClicked: { row.dev.forget(); page.expanded = "" } }
                    }
                }
            }

            SectionLabel { text: "In der Nähe"; Layout.topMargin: page.paired.length ? 6 : 0 }
            Repeater {
                model: page.nearby
                delegate: ListRow {
                    required property var modelData
                    readonly property var dev: modelData
                    icon: dev.pairing ? "󰑓" : page.deviceIcon(dev.icon)
                    busy: dev.pairing
                    title: dev.name
                    sub: dev.pairing ? "Kopple … (ggf. Code am Gerät bestätigen)" : "Klicken zum Koppeln"
                    // Koppeln, danach vertrauen und verbinden (nicht jedes Gerät verbindet sich selbst)
                    onClicked: if (!dev.pairing) { dev.trusted = true; dev.pair() }
                    Connections {
                        target: dev
                        function onPairedChanged() { if (dev.paired) dev.connect() }
                    }
                }
            }
            Text {
                visible: page.nearby.length === 0
                Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4
                horizontalAlignment: Text.AlignHCenter
                text: "Suche Geräte … (Gerät in den Kopplungsmodus versetzen)"
                wrapMode: Text.WordWrap
                color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
    }

    ActionButton {
        text: "󰒓  Bluetooth-Manager"
        onClicked: { Panels.close(); Quickshell.execDetached(["blueman-manager"]) }
    }

    component SectionLabel: Text {
        Layout.leftMargin: 4
        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; font.bold: true
        font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8
    }
}

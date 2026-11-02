import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services
import qs.panels.quick

// Quick Settings (SUPER+S, ⚙): WLAN, Bluetooth, Nicht stören, Energie; Lautstärke, Helligkeit; Medien.
// Pfeil an den Kacheln → Unterseiten WLAN/Bluetooth/Audio (Panels.page)
DropPanel {
    id: root
    panel: "quick"
    ns: "qs-quick-settings"

    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifiDev?.networks?.values.find(n => n.connected) ?? null
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btConnected: bt?.devices?.values.find(d => d.connected) ?? null
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    readonly property int profileIdx: Math.max(0, profiles.indexOf(PowerProfiles.profile))
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    PwObjectTracker { objects: [root.sink] }

    // Helligkeit: lesen über sysfs, setzen über brightnessctl
    property real brightness: 0
    FileView { id: bri; path: "/sys/class/backlight/intel_backlight/brightness"; blockLoading: true }
    FileView { id: briMax; path: "/sys/class/backlight/intel_backlight/max_brightness"; blockLoading: true }
    function readBrightness() { bri.reload(); brightness = Number(bri.text()) / Math.max(1, Number(briMax.text())) }
    onShownChanged: if (shown) readBrightness()
    Process { id: setBri }
    function setBrightness(v) {
        brightness = v
        setBri.command = ["brightnessctl", "-q", "set", Math.round(v * 100) + "%"]
        setBri.running = true
    }

    WifiPage { visible: Panels.page === "wifi"; active: root.shown && visible; Layout.fillWidth: true }
    BluetoothPage { visible: Panels.page === "bluetooth"; active: root.shown && visible; Layout.fillWidth: true }
    AudioPage { visible: Panels.page === "audio"; active: root.shown && visible; Layout.fillWidth: true }

    ColumnLayout {
    id: mainPage
    visible: Panels.page === "main"
    Layout.fillWidth: true
    spacing: 12

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 8
        columnSpacing: 8
        Tile {
            icon: !Networking.wifiEnabled ? "󰤮" : (root.wifiNet?.signalStrength ?? 0) > 0.66 ? "󰤨" : (root.wifiNet?.signalStrength ?? 0) > 0.33 ? "󰤥" : "󰤟"
            title: "WLAN"
            sub: root.wifiNet?.name ?? (Networking.wifiEnabled ? "Nicht verbunden" : "Aus")
            on: Networking.wifiEnabled
            detail: true
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            onDetailClicked: Panels.page = "wifi"
        }
        Tile {
            icon: "󰂯"
            title: "Bluetooth"
            sub: root.btConnected?.name ?? (root.bt?.enabled ? "An" : "Aus")
            on: root.bt?.enabled ?? false
            detail: true
            onClicked: if (root.bt) root.bt.enabled = !root.bt.enabled
            onDetailClicked: Panels.page = "bluetooth"
        }
        Tile {
            icon: Notifs.dnd ? "󰂛" : "󰂚"
            title: "Nicht stören"
            sub: Notifs.dnd ? "An" : "Aus"
            on: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        Tile {
            icon: ["󰌪", "󰗑", ""][root.profileIdx]
            title: "Energie"
            sub: ["Sparsam", "Ausgewogen", "Leistung"][root.profileIdx]
            on: root.profileIdx !== 1
            onClicked: PowerProfiles.profile = root.profiles[(root.profileIdx + 1) % 3]
        }
    }

    // Regler
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text {
            readonly property real v: root.sink?.audio?.volume ?? 0
            text: (root.sink?.audio?.muted || v === 0) ? "󰝟" : v > 0.5 ? "󰕾" : "󰖀"
            color: Theme.primary; font.pixelSize: 18; font.family: Theme.fontUi
            Layout.preferredWidth: 26
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted }
        }
        ThemeSlider {
            Layout.fillWidth: true
            value: root.sink?.audio?.volume ?? 0
            onMoved: v => { if (root.sink?.audio) root.sink.audio.volume = v }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text { text: "󰃟"; color: Theme.primary; font.pixelSize: 18; font.family: Theme.fontUi; Layout.preferredWidth: 26 }
        ThemeSlider {
            Layout.fillWidth: true
            minimum: 0.05
            value: root.brightness
            onMoved: v => root.setBrightness(v)
        }
    }

    // Medien
    Rectangle {
        visible: root.player !== null
        Layout.fillWidth: true
        implicitHeight: 84
        radius: 14
        color: Theme.surfaceContainerHigh
        RowLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 64; Layout.preferredHeight: 64
                radius: 10
                color: Theme.surfaceContainerHighest
                clip: true
                Image { anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
                Text { anchors.centerIn: parent; text: "󰝚"; color: Theme.fgMuted; font.pixelSize: 24; visible: !(root.player?.trackArtUrl) }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: root.player?.trackTitle || "Unbekannt"; color: Theme.fg; font.bold: true; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: root.player?.trackArtist || root.player?.identity || ""; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [
                            { icon: "󰒮", act: () => root.player.previous() },
                            { icon: root.player?.isPlaying ? "󰏤" : "󰐊", act: () => root.player.togglePlaying() },
                            { icon: "󰒭", act: () => root.player.next() }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: 34; implicitHeight: 26; radius: 8
                            color: mBtn.containsMouse ? Theme.primary : "transparent"
                            Text { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 16; font.family: Theme.fontUi; color: mBtn.containsMouse ? Theme.fgOnPrimary : Theme.fg }
                            MouseArea { id: mBtn; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.act() }
                        }
                    }
                }
            }
        }
    }

    // Knöpfe unten
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { label: "󰓃  Audio", wide: true, act: () => Panels.page = "audio" },
                { label: "󰌾", wide: false, act: () => { Panels.close(); Quickshell.execDetached(["loginctl", "lock-session"]) } },
                { label: "󰐥", wide: false, act: () => { Panels.close(); Power.toggle() } }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: modelData.wide
                implicitWidth: 44; implicitHeight: 36; radius: 12
                color: bBtn.containsMouse ? Theme.primary : Theme.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: modelData.label; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; color: bBtn.containsMouse ? Theme.fgOnPrimary : Theme.fg }
                MouseArea { id: bBtn; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.act() }
            }
        }
    }
    }
}

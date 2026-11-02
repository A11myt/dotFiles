import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs

// Bildschirmanzeige unten mittig:
// - Lautstärke und Mikrofon (PipeWire, automatisch), Helligkeit (`qs ipc call osd brightness`)
// - Hinweise: Ausgabegerät gewechselt, Bluetooth-Gerät verbunden/getrennt (mit Akku)
PanelWindow {
    id: win
    property string icon: ""
    property real value: 0
    property bool muted: false
    property string label: ""          // gesetzt → Hinweis statt Balken
    property string detail: ""         // Zusatz rechts (z. B. „stumm“, Akku)
    property bool ready: false

    visible: false
    anchors.bottom: true
    margins.bottom: 80
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"
    color: "transparent"
    implicitWidth: label ? Math.max(300, labelText.implicitWidth + 120) : 300
    implicitHeight: 52

    function show(icon, value, muted) {
        if (!ready) return
        win.label = ""; win.icon = icon; win.value = value; win.muted = muted
        win.detail = muted ? "stumm" : Math.round(value * 100) + "%"
        visible = true
        hideTimer.restart()
    }
    function notice(icon, label, detail) {
        if (!ready) return
        win.icon = icon; win.label = label; win.detail = detail ?? ""; win.muted = false
        visible = true
        hideTimer.restart()
    }
    Timer { id: hideTimer; interval: win.label ? 2200 : 1400; onTriggered: win.visible = false }
    Timer { interval: 2500; running: true; onTriggered: win.ready = true }   // Startwerte nicht anzeigen

    // ── Lautstärke ──
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [win.sink, win.source] }
    function deviceName(n) { return n?.nickname || n?.description || n?.name || "?" }
    function isHeadphone(n) { const s = ((n?.name ?? "") + (n?.description ?? "")).toLowerCase(); return s.includes("bluez") || s.includes("headphone") || s.includes("headset") }
    function showVolume() {
        const v = sink?.audio?.volume ?? 0, m = sink?.audio?.muted ?? false
        show(m || v === 0 ? "󰝟" : isHeadphone(sink) ? "󰋋" : v > 0.5 ? "󰕾" : "󰖀", v, m)
    }
    Connections { target: win.sink?.audio ?? null; function onVolumesChanged() { win.showVolume() } function onMutedChanged() { win.showVolume() } }

    // ── Mikrofon (Stummschalten per Taste) ──
    Connections {
        target: win.source?.audio ?? null
        function onMutedChanged() { win.notice(win.source.audio.muted ? "󰍭" : "󰍬", win.source.audio.muted ? "Mikrofon stumm" : "Mikrofon an", "") }
    }

    // ── Ausgabegerät gewechselt ──
    property string lastSink: ""
    onSinkChanged: {
        const name = sink?.name ?? ""
        if (lastSink && name && name !== lastSink) sinkNotice.restart()   // kurz warten, bis Beschreibung da ist
        lastSink = name
    }
    Timer { id: sinkNotice; interval: 300; onTriggered: win.notice(win.isHeadphone(win.sink) ? "󰋋" : "󰓃", win.deviceName(win.sink), "Ausgabe") }

    // ── Bluetooth verbunden/getrennt ──
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                const d = modelData
                if (d.connected) batteryLater.start()
                else win.notice("󰂲", d.name, "getrennt")
            }
            // Akku kommt oft erst kurz nach dem Verbinden
            property Timer batteryLater: Timer {
                interval: 1500
                onTriggered: win.notice("󰂱", modelData.name, modelData.batteryAvailable ? `󰁹 ${Math.round(modelData.battery * 100)} %` : "verbunden")
            }
        }
    }

    // ── Helligkeit ──
    FileView { id: bri; path: "/sys/class/backlight/intel_backlight/brightness"; blockLoading: true }
    FileView { id: briMax; path: "/sys/class/backlight/intel_backlight/max_brightness"; blockLoading: true }
    IpcHandler {
        target: "osd"
        function brightness(): void {
            bri.reload()
            const v = Number(bri.text()) / Math.max(1, Number(briMax.text()))
            win.show(v > 0.66 ? "󰃠" : v > 0.33 ? "󰃟" : "󰃞", v, false)
        }
        function volume(): void { win.showVolume() }
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Qt.alpha(Theme.surfaceContainerHigh, 0.95)
        border.width: 1
        border.color: Theme.outlineVariant
        RowLayout {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
            spacing: 12
            Text { text: win.icon; color: win.muted ? Theme.fgMuted : Theme.primary; font.pixelSize: 22; font.family: Theme.fontUi }
            Text {
                id: labelText
                visible: win.label !== ""
                Layout.fillWidth: true
                text: win.label
                color: Theme.fg
                font.family: Theme.fontUi; font.pixelSize: Theme.fontPx + 1; font.bold: true
                elide: Text.ElideRight
            }
            Rectangle {
                visible: win.label === ""
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.surfaceContainerHighest
                Rectangle {
                    width: parent.width * Math.min(1, win.value)
                    height: parent.height
                    radius: 4
                    color: win.muted ? Theme.fgMuted : Theme.primary
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                visible: text !== ""
                text: win.detail
                color: win.muted ? Theme.fgMuted : (win.label ? Theme.fgMuted : Theme.fg)
                font.family: win.label ? Theme.fontUi : Theme.fontAccent; font.pixelSize: win.label ? 12 : 13
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: win.label ? 0 : 46
            }
        }
    }
}

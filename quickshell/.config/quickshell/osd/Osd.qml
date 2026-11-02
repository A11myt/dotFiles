import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs

// Bildschirmanzeige unten mittig: Lautstärke (PipeWire, automatisch) und Helligkeit
// (per `qs ipc call osd brightness` aus den Helligkeitstasten – dafür gibt es kein Modul)
PanelWindow {
    id: win
    property string icon: ""
    property real value: 0
    property bool muted: false
    property bool ready: false

    visible: false
    anchors.bottom: true
    margins.bottom: 80
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"
    color: "transparent"
    implicitWidth: 300
    implicitHeight: 52

    function show(icon, value, muted) {
        if (!ready) return
        win.icon = icon; win.value = value; win.muted = muted
        visible = true
        hideTimer.restart()
    }
    Timer { id: hideTimer; interval: 1400; onTriggered: win.visible = false }
    Timer { interval: 1500; running: true; onTriggered: win.ready = true }   // Startwerte nicht anzeigen

    // Lautstärke
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [win.sink] }
    function showVolume() {
        const v = sink?.audio?.volume ?? 0, m = sink?.audio?.muted ?? false
        show(m || v === 0 ? "󰝟" : v > 0.5 ? "󰕾" : "󰖀", v, m)
    }
    Connections { target: win.sink?.audio ?? null; function onVolumesChanged() { win.showVolume() } function onMutedChanged() { win.showVolume() } }

    // Helligkeit
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
            Rectangle {
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
                text: win.muted ? "stumm" : Math.round(win.value * 100) + "%"
                color: win.muted ? Theme.fgMuted : Theme.fg
                font.family: Theme.fontAccent; font.pixelSize: 13
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 46
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// Screenshot-Werkzeug (Print = Bereich, Shift+Print = Fenster, Strg+Print = Bildschirm).
// Friert den Bildschirm ein (grim → Vollbild), man wählt auf dem Standbild aus,
// scripts/screenshot.sh schneidet zu, speichert, kopiert und benachrichtigt.
PanelWindow {
    id: win
    property string mode: "region"            // region | window | screen
    property bool active: false
    property bool editAfter: false
    property bool video: false              // Video statt Foto (Alt+Druck)
    property bool audio: false              // Systemton mit aufnehmen
    property bool hasSatty: false
    property string stamp: ""
    readonly property var mon: Hyprland.focusedMonitor
    readonly property string full: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-screenshot.ppm"   // unkomprimiert: 0,1 s statt 2 s

    screen: Quickshell.screens.find(s => s.name === mon?.name) ?? Quickshell.screens[0]
    visible: active
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-screenshot"
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "black"

    IpcHandler {
        target: "screenshot"
        function region(): void { win.video = false; win.start("region") }
        function window(): void { win.video = false; win.start("window") }
        function screen(): void { win.video = false; win.start("screen") }
        // Video: Auswahl wie beim Screenshot; läuft schon eine Aufnahme → stoppen
        function record(): void { if (Recorder.recording) Recorder.stop(); else { win.video = true; win.start("region") } }
        function cancel(): void { win.cancel() }
    }

    Process {
        command: ["bash", "-c", "command -v satty"]
        running: true
        onExited: code => win.hasSatty = code === 0
    }

    // 1. Standbild aufnehmen
    Process {
        id: grab
        property string want: "region"
        onExited: code => {
            if (code !== 0) { Quickshell.execDetached(["notify-send", "-a", "Screenshot", "Screenshot fehlgeschlagen", "grim konnte den Bildschirm nicht aufnehmen"]); return }
            if (want === "screen") { win.video ? win.finish(Qt.rect(0, 0, win.width, win.height)) : win.finishFull(); return }
            win.stamp = String(Date.now())
            win.mode = want
            win.sel = Qt.rect(0, 0, 0, 0)
            Hyprland.refreshToplevels()
            win.active = true
            keys.forceActiveFocus()
        }
    }
    function start(m) {
        if (active || grab.running) return
        grab.want = m
        grab.command = ["grim", "-t", "ppm", "-o", mon?.name ?? "", full]
        grab.running = true
    }

    // 2. Auswahl (logische Koordinaten des Overlays)
    property rect sel: Qt.rect(0, 0, 0, 0)
    property point anchorPt: Qt.point(0, 0)
    property bool dragging: false
    readonly property var hoverWin: (mode === "window" || (mode === "region" && !dragging)) ? windowAt(mouse.mouseX, mouse.mouseY) : null

    // Fenster der sichtbaren Arbeitsfläche, schwebende zuerst (liegen oben)
    readonly property var windows: Hyprland.toplevels.values
        .filter(t => t.workspace && t.workspace.id === mon?.activeWorkspace?.id && t.lastIpcObject?.at)
        .sort((a, b) => (b.lastIpcObject.floating ?? false) - (a.lastIpcObject.floating ?? false))
    function windowRect(t) {
        const o = t.lastIpcObject
        return Qt.rect(o.at[0] - (mon?.x ?? 0), o.at[1] - (mon?.y ?? 0), o.size[0], o.size[1])
    }
    function windowAt(x, y) {
        for (const t of windows) {
            const r = windowRect(t)
            if (x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height) return t
        }
        return null
    }
    readonly property rect shown: dragging || sel.width > 0 ? sel
                                : hoverWin ? windowRect(hoverWin)
                                : mode === "screen" ? Qt.rect(0, 0, width, height) : Qt.rect(0, 0, 0, 0)

    // 3. Fertig: in Bildpixel umrechnen (Skalierung) und an das Skript geben
    // Video: Overlay erst verschwinden lassen, dann aufnehmen (sonst ist es im ersten Bild)
    property string recTarget: ""
    Timer { id: recDelay; interval: 250; onTriggered: Recorder.start(win.recTarget, win.audio) }
    function finish(r) {
        if (r.width < 2 || r.height < 2) return
        if (video) {
            active = false
            Quickshell.execDetached(["rm", "-f", full])
            const whole = r.width >= width - 1 && r.height >= height - 1
            // wf-recorder erwartet logische Koordinaten im Gesamtlayout (wie slurp)
            recTarget = whole ? "output:" + (mon?.name ?? "") : `${Math.round((mon?.x ?? 0) + r.x)},${Math.round((mon?.y ?? 0) + r.y)} ${Math.round(r.width)}x${Math.round(r.height)}`
            recDelay.restart()
            return
        }
        const sx = backdrop.implicitWidth / Math.max(1, width), sy = backdrop.implicitHeight / Math.max(1, height)
        const x = Math.max(0, Math.round(r.x * sx)), y = Math.max(0, Math.round(r.y * sy))
        const w = Math.min(Math.round(r.width * sx), backdrop.implicitWidth - x), h = Math.min(Math.round(r.height * sy), backdrop.implicitHeight - y)
        active = false
        Quickshell.execDetached([Quickshell.shellDir + "/scripts/screenshot.sh", full, String(x), String(y), String(w), String(h), editAfter && hasSatty ? "1" : "0"])
    }
    function finishFull() {
        // ganzer Bildschirm ohne Overlay: Bildgröße per Skript (magick -crop mit 100 % schneidet nichts)
        Quickshell.execDetached(["bash", "-c", `read w h < <(magick identify -format "%w %h" "$1"); "$2" "$1" 0 0 "$w" "$h" 0`, "_", full, Quickshell.shellDir + "/scripts/screenshot.sh"])
    }
    function cancel() { active = false; Quickshell.execDetached(["rm", "-f", full]) }

    // ── Standbild + Abdunkeln außerhalb der Auswahl ──
    Image {
        id: backdrop
        anchors.fill: parent
        source: win.active ? "file://" + win.full + "?" + win.stamp : ""
        cache: false
        smooth: true
    }
    Item {
        anchors.fill: parent
        readonly property color dim: Qt.alpha("black", 0.45)
        readonly property rect r: win.shown
        Rectangle { x: 0; y: 0; width: parent.width; height: parent.r.y; color: parent.dim }
        Rectangle { x: 0; y: parent.r.y + parent.r.height; width: parent.width; height: parent.height - y; color: parent.dim }
        Rectangle { x: 0; y: parent.r.y; width: parent.r.x; height: parent.r.height; color: parent.dim }
        Rectangle { x: parent.r.x + parent.r.width; y: parent.r.y; width: parent.width - x; height: parent.r.height; color: parent.dim }
        Rectangle {
            x: parent.r.x - 1; y: parent.r.y - 1; width: parent.r.width + 2; height: parent.r.height + 2
            visible: parent.r.width > 0
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
        }
        Rectangle {   // Größe
            visible: parent.r.width > 0
            x: Math.min(parent.r.x, parent.width - width - 8)
            y: parent.r.y > 34 ? parent.r.y - 30 : parent.r.y + 6
            implicitWidth: sizeTxt.implicitWidth + 16; implicitHeight: 24; radius: 8
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.95)
            Text {
                id: sizeTxt
                anchors.centerIn: parent
                readonly property real s: backdrop.implicitWidth / Math.max(1, win.width)
                text: win.hoverWin && !win.dragging && win.sel.width === 0 ? `${win.hoverWin.lastIpcObject?.class ?? ""}  ·  ${Math.round(parent.parent.r.width * s)} × ${Math.round(parent.parent.r.height * s)}`
                                                                          : `${Math.round(parent.parent.r.width * s)} × ${Math.round(parent.parent.r.height * s)}`
                color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: win.mode === "region" ? Qt.CrossCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: e => {
            if (e.button === Qt.RightButton) { win.cancel(); return }
            if (win.mode !== "region") return
            win.anchorPt = Qt.point(e.x, e.y)
            win.sel = Qt.rect(e.x, e.y, 0, 0)
        }
        onPositionChanged: e => {
            if (!pressed || win.mode !== "region") return
            if (!win.dragging && Math.abs(e.x - win.anchorPt.x) + Math.abs(e.y - win.anchorPt.y) < 4) return
            win.dragging = true
            win.sel = Qt.rect(Math.min(e.x, win.anchorPt.x), Math.min(e.y, win.anchorPt.y), Math.abs(e.x - win.anchorPt.x), Math.abs(e.y - win.anchorPt.y))
        }
        onReleased: e => {
            if (e.button === Qt.RightButton) return
            const wasDrag = win.dragging
            win.dragging = false
            if (win.mode === "screen") win.finish(Qt.rect(0, 0, win.width, win.height))
            else if (wasDrag) win.finish(win.sel)
            else {   // einfacher Klick: Fenster darunter (im Bereichsmodus sonst ganzer Bildschirm)
                win.sel = Qt.rect(0, 0, 0, 0)
                const t = win.windowAt(e.x, e.y)
                win.finish(t ? win.windowRect(t) : Qt.rect(0, 0, win.width, win.height))
            }
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) win.cancel()
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.finish(win.sel.width > 0 ? win.sel : Qt.rect(0, 0, win.width, win.height))
            else if (e.key === Qt.Key_R || e.key === Qt.Key_1) win.mode = "region"
            else if (e.key === Qt.Key_F || e.key === Qt.Key_2) win.mode = "window"
            else if (e.key === Qt.Key_B || e.key === Qt.Key_3) win.mode = "screen"
            else if (e.key === Qt.Key_E && win.hasSatty) win.editAfter = !win.editAfter
            else if (e.key === Qt.Key_V) win.video = !win.video
            else if (e.key === Qt.Key_T && win.video) win.audio = !win.audio
            else return
            e.accepted = true
        }
    }

    // ── Werkzeugleiste ──
    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 36 }
        implicitWidth: bar.implicitWidth + 20
        implicitHeight: 48
        radius: 16
        color: Qt.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Theme.outlineVariant
        // nicht durch die Auswahl-Maus greifen
        MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons }

        RowLayout {
            id: bar
            anchors.centerIn: parent
            spacing: 6
            Repeater {
                model: [{ m: "region", t: "󰩭  Bereich", k: "R" }, { m: "window", t: "󰖯  Fenster", k: "F" }, { m: "screen", t: "󰍹  Bildschirm", k: "B" }]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: win.mode === modelData.m
                    implicitWidth: chipTxt.implicitWidth + 24; implicitHeight: 34; radius: 10
                    color: sel ? Theme.primary : (chipMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                    Text { id: chipTxt; anchors.centerIn: parent; text: modelData.t; color: parent.sel ? Theme.fgOnPrimary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                    MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.mode = modelData.m; win.sel = Qt.rect(0, 0, 0, 0) } }
                }
            }
            Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.outlineVariant }
            // Foto / Video
            Repeater {
                model: [{ v: false, t: "󰄀  Foto" }, { v: true, t: "󰕧  Video" }]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: win.video === modelData.v
                    implicitWidth: kindTxt.implicitWidth + 24; implicitHeight: 34; radius: 10
                    color: sel ? (modelData.v ? Theme.error : Theme.primary) : (kindMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                    Text { id: kindTxt; anchors.centerIn: parent; text: modelData.t; color: parent.sel ? (modelData.v ? Theme.fgOnError : Theme.fgOnPrimary) : Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                    MouseArea { id: kindMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.video = modelData.v }
                }
            }
            Rectangle {
                visible: win.video
                implicitWidth: audioTxt.implicitWidth + 24; implicitHeight: 34; radius: 10
                color: win.audio ? Qt.alpha(Theme.primary, 0.2) : (audioMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                Text { id: audioTxt; anchors.centerIn: parent; text: (win.audio ? "󰕾" : "󰖁") + "  Ton"; color: win.audio ? Theme.primary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                MouseArea { id: audioMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.audio = !win.audio }
            }
            Rectangle { implicitWidth: 1; implicitHeight: 24; color: Theme.outlineVariant }
            Rectangle {
                visible: win.hasSatty && !win.video
                implicitWidth: editTxt.implicitWidth + 24; implicitHeight: 34; radius: 10
                color: win.editAfter ? Qt.alpha(Theme.primary, 0.2) : (editMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                Text { id: editTxt; anchors.centerIn: parent; text: (win.editAfter ? "󰄬 " : "") + "󰏫  Bearbeiten"; color: win.editAfter ? Theme.primary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                MouseArea { id: editMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.editAfter = !win.editAfter }
            }
            Text {
                Layout.leftMargin: 6; Layout.rightMargin: 4
                text: win.mode === "region" ? "Ziehen · Klick = Fenster · Enter = alles · Esc" : win.mode === "window" ? "Fenster anklicken · Esc" : "Klicken oder Enter · Esc"
                color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
    }
}

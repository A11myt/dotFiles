import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Info-Leiste rechts (SUPER+B): Uhrzeit, Wetter, System mit Verläufen, Prozesse, Akkus.
// Messwerte laufen nur, solange die Leiste offen ist (Verlauf bleibt erhalten).
PanelWindow {
    id: win
    property bool open: false

    visible: open || closing.running
    onOpenChanged: {
        if (open) { Panels.close(); scroller.contentY = 0; fast.restart(); fastProc.running = true; slowProc.running = true; weatherProc.running = true; keys.forceActiveFocus() }
        else closing.restart()
    }
    Timer { id: closing; interval: Theme.anim + 40 }

    anchors { top: true; bottom: true; right: true }
    margins { top: 6; bottom: 10; right: 10 }
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-sidebar"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: 400

    IpcHandler { target: "sidebar"; function toggle(): void { win.open = !win.open } }
    Connections { target: Panels; function onOpenChanged() { if (Panels.open !== "none") win.open = false } }

    // ── Messwerte ────────────────────────────────────────────────────────────
    readonly property int histLen: 45
    property var cpuHist: []
    property var memHist: []
    property var netHist: []          // Bytes/s (rx+tx)
    property real cpu: 0
    property real memUsed: 0
    property real memTotal: 1
    property real temp: 0
    property real rxRate: 0
    property real txRate: 0
    property int uptime: 0
    property var last: null
    readonly property int cores: 4

    function push(arr, v) { const a = arr.concat([v]); return a.length > histLen ? a.slice(a.length - histLen) : a }

    // offen alle 2 s, sonst alle 5 s weiter messen → beim Öffnen ist schon ein Verlauf da
    Timer { id: fast; interval: win.open ? 2000 : 5000; repeat: true; running: true; onTriggered: fastProc.running = true }
    Process {
        id: fastProc
        command: [Quickshell.shellDir + "/scripts/sysstat.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}
                for (const l of text.split("\n")) { const p = l.trim().split(/\s+/); if (p[0]) v[p[0]] = p.slice(1).map(Number) }
                const now = Date.now()
                if (win.last && v.cpu) {
                    const dt = (now - win.last.t) / 1000
                    const busy = v.cpu[0] - win.last.cpu[0], idle = v.cpu[1] - win.last.cpu[1]
                    win.cpu = busy + idle > 0 ? busy / (busy + idle) : 0
                    win.rxRate = Math.max(0, (v.net[0] - win.last.net[0]) / dt)
                    win.txRate = Math.max(0, (v.net[1] - win.last.net[1]) / dt)
                    win.cpuHist = win.push(win.cpuHist, win.cpu)
                    win.netHist = win.push(win.netHist, win.rxRate + win.txRate)
                }
                if (v.mem) { win.memTotal = v.mem[0]; win.memUsed = v.mem[0] - v.mem[1]; win.memHist = win.push(win.memHist, win.memUsed / win.memTotal) }
                if (v.temp) win.temp = v.temp[0] / 1000
                if (v.uptime) win.uptime = v.uptime[0]
                win.last = { t: now, cpu: v.cpu, net: v.net }
            }
        }
    }

    property var slow: ({ procs: [], disk: { size: 1, used: 0 }, bats: [] })
    Timer { interval: 10000; repeat: true; running: win.open; onTriggered: slowProc.running = true }
    Process {
        id: slowProc
        command: [Quickshell.shellDir + "/scripts/slowstat.sh"]
        stdout: StdioCollector { onStreamFinished: { try { win.slow = JSON.parse(text) } catch (e) {} } }
    }

    property var wx: ({})
    Timer { interval: 15 * 60000; repeat: true; running: win.open; onTriggered: weatherProc.running = true }
    Process {
        id: weatherProc
        command: [Quickshell.shellDir + "/scripts/forecast.sh"]
        stdout: StdioCollector { onStreamFinished: { try { win.wx = JSON.parse(text) } catch (e) {} } }
    }

    // ── Hilfen ───────────────────────────────────────────────────────────────
    function bytes(b) { const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0; while (b >= 1024 && i < 4) { b /= 1024; i++ } return (i ? b.toFixed(b < 10 ? 1 : 0) : Math.round(b)) + " " + u[i] }
    function rate(b) { return bytes(b) + "/s" }
    function wxIcon(code, day) {
        if (code === 0) return day ? "󰖙" : "󰖔"
        if (code <= 2) return day ? "󰖕" : "󰼱"
        if (code === 3) return "󰖐"
        if (code === 45 || code === 48) return "󰖑"
        if (code >= 95) return "󰙾"
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "󰖘"
        if (code >= 51) return "󰖗"
        return "󰖐"
    }
    function wxText(code) {
        return code === 0 ? "Klar" : code <= 2 ? "Leicht bewölkt" : code === 3 ? "Bedeckt" : code <= 48 ? "Nebel"
             : code <= 57 ? "Nieselregen" : code <= 67 ? "Regen" : code <= 77 ? "Schnee" : code <= 82 ? "Schauer"
             : code <= 86 ? "Schneeschauer" : "Gewitter"
    }
    readonly property var hours: {
        const h = wx.hourly; if (!h) return []
        const now = new Date(); let i = h.time.findIndex(t => new Date(t) >= now)
        if (i < 0) return []
        const out = []
        for (let k = i; k < Math.min(i + 24, h.time.length); k += 3)
            out.push({ t: h.time[k].slice(11, 13), temp: Math.round(h.temperature_2m[k]), code: h.weather_code[k], day: h.is_day[k], rain: h.precipitation_probability[k] })
        return out
    }
    readonly property var days: {
        const d = wx.daily; if (!d) return []
        return d.time.slice(0, 6).map((t, i) => ({
            name: i === 0 ? "Heute" : i === 1 ? "Morgen" : new Date(t).toLocaleDateString(Qt.locale("de_DE"), "dddd"),
            max: Math.round(d.temperature_2m_max[i]), min: Math.round(d.temperature_2m_min[i]),
            code: d.weather_code[i], rain: d.precipitation_probability_max[i]
        }))
    }
    readonly property real weekMin: Math.min(...days.map(d => d.min), 99)
    readonly property real weekMax: Math.max(...days.map(d => d.max), -99)

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ── Oberfläche ───────────────────────────────────────────────────────────
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 18
        color: Qt.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Theme.outlineVariant
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        transform: Translate {
            x: win.open ? 0 : 40
            Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        }
        Item { id: keys; focus: true; Keys.onEscapePressed: win.open = false }

        Flickable {
            id: scroller
            anchors { fill: parent; margins: 16 }
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 14

                // ── Kopf ──
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 0
                        Text { text: Qt.formatTime(clock.date, "HH:mm"); color: Theme.fg; font.family: Theme.fontAccent; font.pixelSize: 46 }
                        Text { text: clock.date.toLocaleDateString(Qt.locale("de_DE"), "dddd, d. MMMM"); color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        Text { Layout.alignment: Qt.AlignRight; text: "󰔟 " + Math.floor(win.uptime / 3600) + " h " + Math.floor(win.uptime % 3600 / 60) + " min"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }
                        Text { Layout.alignment: Qt.AlignRight; text: "seit dem Start"; color: Theme.outline; font.family: Theme.fontUi; font.pixelSize: 10 }
                    }
                }

                // ── Wetter ──
                Card {
                    visible: win.wx.current !== undefined
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text { text: win.wxIcon(win.wx.current?.weather_code ?? 3, win.wx.current?.is_day ?? 1); color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 40 }
                            ColumnLayout {
                                spacing: 0
                                Text { text: Math.round(win.wx.current?.temperature_2m ?? 0) + "°"; color: Theme.fg; font.family: Theme.fontAccent; font.pixelSize: 30 }
                                Text { text: win.wxText(win.wx.current?.weather_code ?? 3); color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12 }
                            }
                            Item { Layout.fillWidth: true }
                            ColumnLayout {
                                spacing: 1
                                Layout.alignment: Qt.AlignRight
                                Small { Layout.alignment: Qt.AlignRight; text: "gefühlt " + Math.round(win.wx.current?.apparent_temperature ?? 0) + "°" }
                                Small { Layout.alignment: Qt.AlignRight; text: "󰖝 " + Math.round(win.wx.current?.wind_speed_10m ?? 0) + " km/h  󰖎 " + (win.wx.current?.relative_humidity_2m ?? 0) + " %" }
                                Small { Layout.alignment: Qt.AlignRight; text: "󰖜 " + (win.wx.daily?.sunrise?.[0]?.slice(11) ?? "") + "  󰖛 " + (win.wx.daily?.sunset?.[0]?.slice(11) ?? "") }
                            }
                        }
                        // nächste Stunden
                        RowLayout {
                                    id: hoursRow
                            Layout.fillWidth: true
                            spacing: 0
                            Repeater {
                                model: win.hours
                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.preferredWidth: hoursRow.width / Math.max(1, win.hours.length)
                                    spacing: 2
                                    Small { Layout.alignment: Qt.AlignHCenter; text: modelData.t }
                                    Text { Layout.alignment: Qt.AlignHCenter; text: win.wxIcon(modelData.code, modelData.day); color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 18 }
                                    Text { Layout.alignment: Qt.AlignHCenter; text: modelData.temp + "°"; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12 }
                                    Small { Layout.alignment: Qt.AlignHCenter; text: modelData.rain >= 20 ? "󰖗" + modelData.rain + "%" : " "; color: Theme.tertiary }
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVariant }
                        // Tage mit Temperaturspanne
                        Repeater {
                            model: win.days
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8
                                Text { Layout.preferredWidth: 78; text: modelData.name; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12 }
                                Text { Layout.preferredWidth: 22; text: win.wxIcon(modelData.code, 1); color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 15 }
                                Small { Layout.preferredWidth: 36; text: modelData.rain >= 20 ? modelData.rain + "%" : ""; color: Theme.tertiary }
                                Small { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignRight; text: modelData.min + "°" }
                                Item {
                                    Layout.fillWidth: true; implicitHeight: 6
                                    Rectangle { anchors.fill: parent; radius: 3; color: Theme.surfaceContainerHighest }
                                    Rectangle {
                                        readonly property real span: Math.max(1, win.weekMax - win.weekMin)
                                        x: parent.width * (modelData.min - win.weekMin) / span
                                        width: Math.max(6, parent.width * (modelData.max - modelData.min) / span)
                                        height: parent.height; radius: 3
                                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.secondary } GradientStop { position: 1; color: Theme.primary } }
                                    }
                                }
                                Text { Layout.preferredWidth: 26; text: modelData.max + "°"; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12 }
                            }
                        }
                    }
                }

                // ── System ──
                Card {
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 12; columnSpacing: 12
                        Meter { title: "󰻠 CPU"; value: Math.round(win.cpu * 100) + " %"; sub: Math.round(win.temp) + " °C"; hist: win.cpuHist; max: 1; warn: win.cpu > 0.85 || win.temp > 85 }
                        Meter { title: "󰍛 RAM"; value: win.bytes(win.memUsed * 1024); sub: "von " + win.bytes(win.memTotal * 1024); hist: win.memHist; max: 1; warn: win.memUsed / win.memTotal > 0.9 }
                        Meter {
                            title: "󰛳 Netz"; value: "↓ " + win.rate(win.rxRate); sub: "↑ " + win.rate(win.txRate)
                            hist: win.netHist; max: Math.max(64 * 1024, ...win.netHist)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 4
                            readonly property real used: win.slow.disk.used / Math.max(1, win.slow.disk.size)
                            Small { text: "󰋊 Speicher"; color: Theme.fgMuted }
                            Text { text: win.bytes(win.slow.disk.used); color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 15; font.bold: true }
                            Small { text: "von " + win.bytes(win.slow.disk.size) + " · " + Math.round(parent.used * 100) + " %" }
                            Rectangle {
                                Layout.fillWidth: true; Layout.topMargin: 6; implicitHeight: 8; radius: 4; color: Theme.surfaceContainerHighest
                                Rectangle { width: parent.width * parent.parent.used; height: parent.height; radius: 4; color: parent.parent.used > 0.9 ? Theme.error : Theme.primary }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVariant }
                    Small { text: "Meiste Last gerade"; color: Theme.fgMuted }
                    Repeater {
                        model: win.slow.procs
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Text { Layout.fillWidth: true; text: modelData.name; color: Theme.fg; font.family: Theme.fontMono; font.pixelSize: 12; elide: Text.ElideRight }
                            Small { text: win.bytes(modelData.mem * 1048576) }
                            Item {
                                Layout.preferredWidth: 70; implicitHeight: 6
                                Rectangle { anchors.fill: parent; radius: 3; color: Theme.surfaceContainerHighest }
                                Rectangle { width: parent.width * Math.min(1, modelData.cpu / 100 / win.cores); height: parent.height; radius: 3; color: Theme.primary }
                            }
                            Text { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; text: (modelData.cpu / win.cores).toFixed(1) + "%"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }
                        }
                    }
                }

                // ── Akkus ──
                Card {
                    Small { text: "Akkus"; color: Theme.fgMuted }
                    Repeater {
                        model: win.slow.bats
                        delegate: ColumnLayout {
                            id: bat
                            required property var modelData
                            readonly property real health: modelData.full / Math.max(1, modelData.design)
                            readonly property bool charging: modelData.status === "Charging"
                            readonly property real hours: modelData.power > 0 ? (charging ? (modelData.full - modelData.now) : modelData.now) / modelData.power : 0
                            Layout.fillWidth: true
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: (bat.charging ? "󰂄 " : "󰁹 ") + (bat.modelData.name === "BAT0" ? "Intern" : "Wechselakku"); color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: true }
                                Item { Layout.fillWidth: true }
                                Small {
                                    text: bat.hours > 0 ? `${bat.charging ? "voll in" : "noch"} ${Math.floor(bat.hours)} h ${Math.round(bat.hours % 1 * 60)} min`
                                        : bat.modelData.status === "Not charging" ? "wartet" : bat.modelData.status === "Full" ? "voll" : bat.charging ? "lädt" : ""
                                }
                                Text { text: bat.modelData.cap + " %"; color: bat.modelData.cap <= 15 ? Theme.error : Theme.primary; font.family: Theme.fontUi; font.pixelSize: 13; font.bold: true }
                            }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: Theme.surfaceContainerHighest
                                Rectangle { width: parent.width * bat.modelData.cap / 100; height: parent.height; radius: 4; color: bat.modelData.cap <= 15 ? Theme.error : Theme.primary }
                                Rectangle {   // Ladegrenze
                                    visible: bat.modelData.end > 0 && bat.modelData.end < 100
                                    x: parent.width * bat.modelData.end / 100 - 1; width: 2; height: parent.height + 4; y: -2; color: Theme.tertiary
                                }
                            }
                            Small { text: `Gesundheit ${Math.round(bat.health * 100)} %  ·  ${bat.modelData.cycles} Ladezyklen  ·  lädt bis ${bat.modelData.end || 100} %` }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 6
                        readonly property bool gentle: win.slow.bats.length > 0 && win.slow.bats.every(b => b.end > 0 && b.end <= 80)
                        Button2 { text: "󰂃  Schonen (80 %)"; on: parent.gentle; onClicked: Quickshell.execDetached(["alacritty", "--class", "floating-term", "-e", "bash", "-c", "akku schonen; akku status; read -p 'Enter zum Schließen'"]) }
                        Button2 { text: "󰁹  Voll laden"; on: !parent.gentle; onClicked: Quickshell.execDetached(["alacritty", "--class", "floating-term", "-e", "bash", "-c", "akku voll; akku status; read -p 'Enter zum Schließen'"]) }
                    }
                }
            }
        }
    }

    // ── Bausteine ────────────────────────────────────────────────────────────
    component Small: Text { color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }

    component Card: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 24
        radius: 14
        color: Theme.surfaceContainerHigh
        ColumnLayout { id: inner; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 } spacing: 8 }
    }

    component Button2: Rectangle {
        id: b2
        property string text
        property bool on: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 32; radius: 10
        color: on ? Qt.alpha(Theme.primary, 0.2) : (b2m.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
        border.width: on ? 1 : 0; border.color: Theme.primary
        Text { anchors.centerIn: parent; text: b2.text; color: b2.on ? Theme.primary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12 }
        MouseArea { id: b2m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b2.clicked() }
    }

    // Kennzahl mit Verlaufskurve
    component Meter: ColumnLayout {
        id: m
        property string title
        property string value
        property string sub
        property var hist: []
        property real max: 1
        property bool warn: false
        Layout.fillWidth: true
        spacing: 2
        Small { text: m.title; color: Theme.fgMuted }
        Text { text: m.value; color: m.warn ? Theme.error : Theme.fg; font.family: Theme.fontUi; font.pixelSize: 15; font.bold: true }
        Small { text: m.sub }
        Canvas {
            id: cv
            Layout.fillWidth: true
            implicitHeight: 34
            property var h: m.hist
            property color line: m.warn ? Theme.error : Theme.primary
            onHChanged: requestPaint()
            onLineChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const n = win.histLen, data = h
                if (data.length < 2) return
                const step = width / (n - 1), off = (n - data.length) * step
                const y = v => height - 2 - (height - 4) * Math.min(1, v / Math.max(1e-9, m.max))
                ctx.beginPath()
                ctx.moveTo(off, y(data[0]))
                for (let i = 1; i < data.length; i++) ctx.lineTo(off + i * step, y(data[i]))
                ctx.strokeStyle = line; ctx.lineWidth = 1.6; ctx.stroke()
                ctx.lineTo(off + (data.length - 1) * step, height); ctx.lineTo(off, height); ctx.closePath()
                ctx.fillStyle = Qt.alpha(line, 0.18); ctx.fill()
            }
        }
    }
}

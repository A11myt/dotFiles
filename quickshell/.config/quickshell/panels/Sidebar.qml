import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services

// Info-Leiste rechts (SUPER+B): Uhrzeit oben, darunter frei wählbare Widgets
// (Config.widgets in config.json). Stift oben rechts = Bearbeiten: ↑ ↓ ✕ pro Widget,
// unten „Widget hinzufügen“. Messwerte laufen im Hintergrund weiter (seltener).
PanelWindow {
    id: win
    property bool open: false
    property bool editing: false

    visible: open || closing.running
    onOpenChanged: {
        if (open) {
            Panels.close(); scroller.contentY = 0; fast.restart()
            fastProc.running = true; slowProc.running = true; weatherProc.running = true; loadNews(false); checkHealth(false)
            if (has("twitch")) Accounts.refreshTwitch(false)
            if (has("mail")) Accounts.refreshMail(false)
            keys.forceActiveFocus()
        } else { closing.restart(); editing = false }
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

    IpcHandler {
        target: "sidebar"
        function toggle(): void { win.open = !win.open }
        function edit(): void { win.open = true; win.editing = !win.editing }
    }
    Connections { target: Panels; function onOpenChanged() { if (Panels.open !== "none") win.open = false } }

    function has(w) { return Config.widgets.indexOf(w) >= 0 }

    // ── Messwerte ────────────────────────────────────────────────────────────
    readonly property int histLen: 45
    property var cpuHist: []
    property var memHist: []
    property var netHist: []
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

    // offen alle 2 s, sonst alle 5 s → beim Öffnen ist schon ein Verlauf da
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
    Timer { interval: 10000; repeat: true; running: win.open && (win.has("processes") || win.has("battery") || win.has("system")); onTriggered: slowProc.running = true }
    Process {
        id: slowProc
        command: [Quickshell.shellDir + "/scripts/slowstat.sh"]
        stdout: StdioCollector { onStreamFinished: { try { win.slow = JSON.parse(text) } catch (e) {} } }
    }

    property var wx: ({})
    Timer { interval: 15 * 60000; repeat: true; running: win.open && win.has("weather"); onTriggered: weatherProc.running = true }
    Process {
        id: weatherProc
        command: [Quickshell.shellDir + "/scripts/forecast.sh"]
        stdout: StdioCollector { onStreamFinished: { try { win.wx = JSON.parse(text) } catch (e) {} } }
    }

    // ── System-Gesundheit ────────────────────────────────────────────────────
    property var health: ({})
    property bool healthRunning: healthProc.running
    FileView {
        id: healthCache
        path: Quickshell.env("HOME") + "/.cache/quickshell/health.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { win.health = JSON.parse(text()) } catch (e) {} }
    }
    function checkHealth(force) {
        if (!has("health") || healthProc.running) return
        if (!force && health.time && Date.now() / 1000 - health.time < 30 * 60) return
        healthProc.running = true
    }
    Process { id: healthProc; command: ["python3", "-I", Quickshell.shellDir + "/scripts/health.py"] }
    readonly property var problems: (health.doctor ?? []).filter(r => r.state !== "ok")
    readonly property string healthState: problems.some(r => r.state === "fail") ? "fail" : problems.length ? "warn" : "ok"

    // ── Nachrichten ──────────────────────────────────────────────────────────
    property var news: []
    property bool newsLoading: false
    property bool newsMore: false
    function loadNews(refresh) {
        if (!has("news") || newsProc.running) return
        newsLoading = true
        newsProc.command = ["python3", "-I", Quickshell.shellDir + "/scripts/news.py", JSON.stringify(Config.feeds)].concat(refresh ? ["--refresh"] : [])
        newsProc.running = true
    }
    Process {
        id: newsProc
        stdout: StdioCollector { onStreamFinished: { try { win.news = JSON.parse(text) } catch (e) {} win.newsLoading = false } }
    }
    Timer { interval: 15 * 60000; repeat: true; running: win.open && win.has("news"); onTriggered: win.loadNews(false) }
    Connections { target: Config; function onFeedsChanged() { if (win.open) win.loadNews(false) } }
    readonly property var shownNews: news.filter(n => n.error || Config.newsHidden.indexOf(n.link) < 0)
                                         .filter(n => Config.newsTopic === "Alle" || Config.topicOf(n.source) === Config.newsTopic)
                                         .slice(0, newsMore ? Config.newsCount * 3 : Config.newsCount)
    function hideNews(link) { Config.set("newsHidden", Config.newsHidden.concat([link]).slice(-300)) }
    function ago(t) {
        if (!t) return ""
        const m = Math.round((Date.now() / 1000 - t) / 60)
        return m < 1 ? "gerade" : m < 60 ? `vor ${m} min` : m < 24 * 60 ? `vor ${Math.round(m / 60)} h` : `vor ${Math.round(m / 1440)} Tagen`
    }
    function sourceColor(name) {
        const c = [Theme.primary, Theme.tertiary, Theme.secondary, Theme.error]
        let h = 0; for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) % 997
        return c[h % c.length]
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
        const now = new Date(); const i = h.time.findIndex(t => new Date(t) >= now)
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

    function move(w, d) {
        const a = Config.widgets.slice(), i = a.indexOf(w), j = i + d
        if (i < 0 || j < 0 || j >= a.length) return
        a[i] = a[j]; a[j] = w
        Config.set("widgets", a)
    }

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
        Item { id: keys; focus: true; Keys.onEscapePressed: win.editing ? win.editing = false : win.open = false }

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

                // ── Kopf (fest) ──
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 0
                        Text { text: Qt.formatTime(clock.date, "HH:mm"); color: Theme.fg; font.family: Theme.fontAccent; font.pixelSize: 46 }
                        Text { text: clock.date.toLocaleDateString(Qt.locale("de_DE"), "dddd, d. MMMM"); color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 6
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        IconButton {
                            Layout.alignment: Qt.AlignRight
                            icon: win.editing ? "󰄬" : "󰏫"
                            label: win.editing ? "Fertig" : ""
                            on: win.editing
                            tip: "Widgets anpassen"
                            onClicked: win.editing = !win.editing
                        }
                        Small { Layout.alignment: Qt.AlignRight; text: "󰔟 " + Math.floor(win.uptime / 3600) + " h " + Math.floor(win.uptime % 3600 / 60) + " min" }
                    }
                }

                // ── Widgets ──
                Repeater {
                    model: Config.widgets
                    delegate: ColumnLayout {
                        id: slot
                        required property string modelData
                        required property int index
                        readonly property var info: Config.widgetInfo[modelData] ?? { name: modelData, icon: "?" }
                        Layout.fillWidth: true
                        spacing: 6
                        // Bearbeiten: kompakte Zeile statt Inhalt
                        Rectangle {
                            visible: win.editing
                            Layout.fillWidth: true
                            implicitHeight: 48; radius: 12
                            color: Theme.surfaceContainerHigh
                            border.width: 1; border.color: Theme.outlineVariant
                            RowLayout {
                                anchors { fill: parent; leftMargin: 14; rightMargin: 8 }
                                spacing: 4
                                Text { text: slot.info.icon; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 18 }
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.leftMargin: 6; spacing: 0
                                    Text { text: slot.info.name; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 13; font.bold: true }
                                    Small { text: slot.info.desc ?? ""; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                IconButton { icon: "󰁝"; enabled: slot.index > 0; onClicked: win.move(slot.modelData, -1) }
                                IconButton { icon: "󰁅"; enabled: slot.index < Config.widgets.length - 1; onClicked: win.move(slot.modelData, 1) }
                                IconButton { icon: "󰅖"; danger: true; onClicked: Config.set("widgets", Config.widgets.filter(w => w !== slot.modelData)) }
                            }
                        }
                        Loader {
                            Layout.fillWidth: true
                            visible: !win.editing
                            sourceComponent: ({ weather: weatherW, news: newsW, media: mediaW, system: systemW, processes: processesW, battery: batteryW, health: healthW, agenda: agendaW, mail: mailW, twitch: twitchW })[slot.modelData] ?? null
                        }
                    }
                }

                // ── Widget hinzufügen ──
                Card {
                    visible: win.editing
                    Small { text: "Widget hinzufügen"; color: Theme.fgMuted }
                    Repeater {
                        model: Object.keys(Config.widgetInfo).filter(w => !win.has(w))
                        delegate: Rectangle {
                            required property string modelData
                            readonly property var info: Config.widgetInfo[modelData]
                            Layout.fillWidth: true
                            implicitHeight: 44; radius: 10
                            color: addM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                spacing: 10
                                Text { text: parent.parent.info.icon; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 18 }
                                ColumnLayout {
                                    spacing: 0; Layout.fillWidth: true
                                    Text { text: parent.parent.parent.info.name; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: true }
                                    Small { text: parent.parent.parent.info.desc }
                                }
                                Text { text: "󰐕"; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 18 }
                            }
                            MouseArea { id: addM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Config.set("widgets", Config.widgets.concat([modelData])); if (modelData === "news") win.loadNews(false) } }
                        }
                    }
                    Small { visible: Object.keys(Config.widgetInfo).every(w => win.has(w)); text: "Alle Widgets sind schon da." }
                    Small { text: "Nachrichtenquellen und mehr: Einstellungen (SUPER+I)"; color: Theme.outline }
                }
            }
        }
    }

    // ═════════════════════════ Widgets ═════════════════════════

    Component {
        id: weatherW
        Card {
            Small { visible: win.wx.current === undefined; text: "Wetter wird geladen …" }
            RowLayout {
                visible: win.wx.current !== undefined
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
                    Small { Layout.alignment: Qt.AlignRight; text: "gefühlt " + Math.round(win.wx.current?.apparent_temperature ?? 0) + "°" }
                    Small { Layout.alignment: Qt.AlignRight; text: "󰖝 " + Math.round(win.wx.current?.wind_speed_10m ?? 0) + " km/h  󰖎 " + (win.wx.current?.relative_humidity_2m ?? 0) + " %" }
                    Small { Layout.alignment: Qt.AlignRight; text: "󰖜 " + (win.wx.daily?.sunrise?.[0]?.slice(11) ?? "") + "  󰖛 " + (win.wx.daily?.sunset?.[0]?.slice(11) ?? "") }
                }
            }
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
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVariant; visible: win.days.length > 0 }
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

    Component {
        id: newsW
        Card {
            RowLayout {
                Layout.fillWidth: true
                Small { text: "󰎕  Nachrichten"; color: Theme.fgMuted; Layout.fillWidth: true }
                Text {
                    text: "󰑓"; color: refreshM.containsMouse ? Theme.primary : Theme.fgMuted
                    font.family: Theme.fontUi; font.pixelSize: 14
                    RotationAnimation on rotation { running: win.newsLoading; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    MouseArea { id: refreshM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.loadNews(true) }
                }
            }
            // Themen-Reiter
            Flow {
                visible: Config.topics.length > 1
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: ["Alle"].concat(Config.topics)
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool sel: Config.newsTopic === modelData || (modelData === "Alle" && Config.topics.indexOf(Config.newsTopic) < 0)
                        implicitWidth: topTxt.implicitWidth + 18; implicitHeight: 24; radius: 8
                        color: sel ? Theme.primary : (topM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
                        Text { id: topTxt; anchors.centerIn: parent; text: modelData; color: parent.sel ? Theme.fgOnPrimary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: 11 }
                        MouseArea { id: topM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Config.set("newsTopic", modelData); win.newsMore = false } }
                    }
                }
            }
            Small { visible: Config.feeds.length === 0; text: "Keine Quellen – in den Einstellungen (SUPER+I → Nachrichten) hinzufügen." }
            Small { visible: Config.feeds.length > 0 && win.news.length === 0; text: win.newsLoading ? "Lade Schlagzeilen …" : "Keine Schlagzeilen" }
            Repeater {
                model: win.shownNews
                delegate: Rectangle {
                    id: item
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: itemCol.implicitHeight + 16
                    radius: 10
                    color: itemM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: itemM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: item.modelData.link ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (item.modelData.link) { Quickshell.execDetached(["xdg-open", item.modelData.link]); win.open = false }
                    }
                    ColumnLayout {
                        id: itemCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10; rightMargin: 26 }
                        spacing: 3
                        RowLayout {
                            spacing: 6
                            Rectangle {
                                implicitWidth: srcTxt.implicitWidth + 10; implicitHeight: 16; radius: 5
                                color: Qt.alpha(win.sourceColor(item.modelData.source), 0.2)
                                Text { id: srcTxt; anchors.centerIn: parent; text: item.modelData.source; color: win.sourceColor(item.modelData.source); font.family: Theme.fontUi; font.pixelSize: 10; font.bold: true }
                            }
                            Small { text: win.ago(item.modelData.time) }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: item.modelData.title
                            color: item.modelData.error ? Theme.error : Theme.fg
                            font.family: Theme.fontUi; font.pixelSize: 12
                            wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                        }
                    }
                    Text {   // Schlagzeile ausblenden
                        visible: itemM.containsMouse || xM.containsMouse
                        anchors { right: parent.right; top: parent.top; margins: 6 }
                        text: "󰅖"; color: xM.containsMouse ? Theme.error : Theme.fgMuted
                        font.family: Theme.fontUi; font.pixelSize: 14
                        MouseArea { id: xM; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.hideNews(item.modelData.link) }
                    }
                }
            }
            Text {
                visible: win.news.length > Config.newsCount
                Layout.alignment: Qt.AlignHCenter
                text: win.newsMore ? "weniger anzeigen" : "mehr anzeigen"
                color: moreM.containsMouse ? Theme.primary : Theme.fgMuted
                font.family: Theme.fontUi; font.pixelSize: 11
                MouseArea { id: moreM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.newsMore = !win.newsMore }
            }
        }
    }

    Component {
        id: healthW
        Card {
            id: hc
            readonly property var ups: win.health.updates?.pkgs ?? []
            readonly property var important: ups.filter(u => u.important)
            readonly property color tone: win.healthState === "fail" ? Theme.error : win.healthState === "warn" ? Theme.tertiary : Theme.primary
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle { width: 12; height: 12; radius: 6; color: hc.tone }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text {
                        text: !win.health.time ? "Noch nicht geprüft"
                            : win.healthState === "ok" ? "Alles in Ordnung"
                            : win.problems.length + (win.problems.length === 1 ? " Hinweis" : " Hinweise")
                        color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 14; font.bold: true
                    }
                    Small { text: win.healthRunning ? "prüfe …" : win.health.time ? "geprüft " + win.ago(win.health.time) + " · " + (win.health.doctor?.length ?? 0) + " Prüfungen" : "" }
                }
                Text {
                    text: "󰑓"; color: hRef.containsMouse ? Theme.primary : Theme.fgMuted
                    font.family: Theme.fontUi; font.pixelSize: 14
                    RotationAnimation on rotation { running: win.healthRunning; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    MouseArea { id: hRef; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.checkHealth(true) }
                }
            }
            // Hinweise aus dotdoctor
            Repeater {
                model: win.problems.slice(0, 5)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    Text { Layout.alignment: Qt.AlignTop; text: modelData.state === "fail" ? "󰅙" : "󰀦"; color: modelData.state === "fail" ? Theme.error : Theme.tertiary; font.family: Theme.fontUi; font.pixelSize: 13 }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { Layout.fillWidth: true; text: modelData.msg; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; wrapMode: Text.WordWrap }
                        Small { Layout.fillWidth: true; visible: text !== ""; text: (modelData.detail ?? []).slice(0, 2).join(" · "); elide: Text.ElideRight }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVariant }
            // Updates
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: hc.ups.length ? "󰚰" : "󰗠"; color: hc.ups.length ? Theme.primary : Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 15 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text {
                        text: hc.ups.length ? `${hc.ups.length} Updates (${hc.ups.filter(u => !u.aur).length} Repo · ${hc.ups.filter(u => u.aur).length} AUR)` : "System ist aktuell"
                        color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12
                    }
                    Small {
                        visible: text !== ""
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: (hc.important.length ? "wichtig: " + hc.important.map(u => u.name).join(", ") : "")
                            + (win.health.updates?.reboot ? (hc.important.length ? " · " : "") + "Neustart nötig (Kernel " + win.health.updates.reboot + ")" : "")
                        color: Theme.tertiary
                    }
                    Small { text: win.health.lastUpgrade ? "letztes Update " + win.ago(win.health.lastUpgrade) : "" }
                }
            }
            // Arch-News seit dem letzten Update: vor dem Aktualisieren lesen
            Rectangle {
                visible: (win.health.archNews ?? []).length > 0
                Layout.fillWidth: true
                implicitHeight: newsCol.implicitHeight + 16
                radius: 10
                color: Qt.alpha(Theme.error, 0.12)
                border.width: 1; border.color: Qt.alpha(Theme.error, 0.4)
                ColumnLayout {
                    id: newsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 4
                    Text { text: "󰀦  Arch-News seit deinem letzten Update – vorher lesen"; color: Theme.error; font.family: Theme.fontUi; font.pixelSize: 11; font.bold: true }
                    Repeater {
                        model: win.health.archNews ?? []
                        delegate: Text {
                            required property var modelData
                            Layout.fillWidth: true
                            text: "• " + modelData.title
                            color: anM.containsMouse ? Theme.primary : Theme.fg
                            font.family: Theme.fontUi; font.pixelSize: 12; wrapMode: Text.WordWrap
                            MouseArea { id: anM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["xdg-open", modelData.link]); win.open = false } }
                        }
                    }
                }
            }
            RowLayout {
                visible: hc.ups.length > 0
                Layout.fillWidth: true
                spacing: 6
                Button2 { text: "󰚰  Jetzt aktualisieren"; onClicked: { win.open = false; Quickshell.execDetached(["alacritty", "-e", "bash", "-c", "yay; echo; read -p 'Fertig – Enter zum Schließen'"]) } }
            }
        }
    }

    Component {
        id: mailW
        Card {
            RowLayout {
                Layout.fillWidth: true
                Small { text: "󰇮  E-Mail" + (Accounts.mail.unread ? "  ·  " + Accounts.mail.unread + " ungelesen" : ""); color: Theme.fgMuted; Layout.fillWidth: true }
                Text {
                    text: "󰑓"; color: mRef.containsMouse ? Theme.primary : Theme.fgMuted
                    font.family: Theme.fontUi; font.pixelSize: 14
                    RotationAnimation on rotation { running: Accounts.mailLoading; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    MouseArea { id: mRef; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Accounts.refreshMail(true) }
                }
            }
            Small { visible: Accounts.mailAccounts.length === 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Noch kein Postfach – Einstellungen (SUPER+I) → Konten" }
            Repeater {
                model: Accounts.mail.accounts ?? []
                delegate: ColumnLayout {
                    id: acc
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: acc.modelData.name; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                        Rectangle {
                            visible: acc.modelData.unread > 0
                            implicitWidth: cnt.implicitWidth + 12; implicitHeight: 18; radius: 9; color: Theme.primary
                            Text { id: cnt; anchors.centerIn: parent; text: acc.modelData.unread; color: Theme.fgOnPrimary; font.family: Theme.fontUi; font.pixelSize: 10; font.bold: true }
                        }
                        Text {
                            visible: !!acc.modelData.web
                            text: "󰏌"; color: webM.containsMouse ? Theme.primary : Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 13
                            MouseArea { id: webM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["xdg-open", acc.modelData.web]); win.open = false } }
                        }
                    }
                    Small { visible: !!acc.modelData.error; text: "󰀦 " + (acc.modelData.error ?? ""); color: Theme.error }
                    Small { visible: !acc.modelData.error && acc.modelData.unread === 0; text: "Keine ungelesenen Mails" }
                    Repeater {
                        model: acc.modelData.mails
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: mailCol.implicitHeight + 12
                            radius: 8
                            color: mailM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                            MouseArea { id: mailM; anchors.fill: parent; hoverEnabled: true; cursorShape: acc.modelData.web ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (acc.modelData.web) { Quickshell.execDetached(["xdg-open", acc.modelData.web]); win.open = false } }
                            ColumnLayout {
                                id: mailCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6; leftMargin: 10; rightMargin: 10 }
                                spacing: 1
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: modelData.from; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight }
                                    Small { text: win.ago(modelData.date) }
                                }
                                Text { Layout.fillWidth: true; text: modelData.subject; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: twitchW
        Card {
            id: tw
            readonly property var chans: Accounts.twitch.channels ?? []
            RowLayout {
                Layout.fillWidth: true
                Small { text: "󰕃  Twitch" + (Accounts.liveCount ? "  ·  " + Accounts.liveCount + " live" : ""); color: Theme.fgMuted; Layout.fillWidth: true }
                Text {
                    text: "󰑓"; color: tRef.containsMouse ? Theme.primary : Theme.fgMuted
                    font.family: Theme.fontUi; font.pixelSize: 14
                    RotationAnimation on rotation { running: Accounts.twitchLoading; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    MouseArea { id: tRef; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Accounts.refreshTwitch(true) }
                }
            }
            Small { visible: Config.twitch.length === 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Noch keine Kanäle – Einstellungen (SUPER+I) → Konten" }
            Small { visible: Config.twitch.length > 0 && tw.chans.length === 0; text: Accounts.twitchLoading ? "Frage Twitch …" : (Accounts.twitch.error ? "Twitch nicht erreichbar" : "") }
            // live: groß mit Titel und Spiel
            Repeater {
                model: tw.chans.filter(c => c.live)
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: liveCol.implicitHeight + 14
                    radius: 10
                    color: liveM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                    MouseArea { id: liveM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["xdg-open", "https://twitch.tv/" + modelData.login]); win.open = false } }
                    ColumnLayout {
                        id: liveCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7; leftMargin: 10; rightMargin: 10 }
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Rectangle { width: 8; height: 8; radius: 4; color: "#eb0400" }
                            Text { text: modelData.login; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: true }
                            Small { Layout.fillWidth: true; text: modelData.game; elide: Text.ElideRight; color: Theme.primary }
                            Small { text: modelData.viewers ? "󰈈 " + modelData.viewers.toLocaleString(Qt.locale("de_DE"), "f", 0) : "" }
                        }
                        Text { Layout.fillWidth: true; text: modelData.title; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                    }
                }
            }
            // offline: kompakt
            Flow {
                visible: tw.chans.some(c => !c.live)
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: tw.chans.filter(c => !c.live)
                    delegate: Text {
                        required property var modelData
                        text: "○ " + modelData.login
                        color: offM.containsMouse ? Theme.primary : Theme.outline
                        font.family: Theme.fontUi; font.pixelSize: 11
                        MouseArea { id: offM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["xdg-open", "https://twitch.tv/" + modelData.login]); win.open = false } }
                    }
                }
            }
        }
    }

    Component {
        id: agendaW
        Card {
            id: ag
            // nächste 7 Tage, nach Tag gruppiert; laufende Termine von heute zählen mit
            readonly property var days: {
                const out = [], now = new Date()
                for (let i = 0; i < 7; i++) {
                    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i)
                    const evs = Calendars.on(d).filter(e => i > 0 || e.allDay || e.end > Date.now() / 1000)
                    if (evs.length) out.push({ d, i, evs })
                }
                return out
            }
            RowLayout {
                Layout.fillWidth: true
                Small { text: "󰃭  Termine"; color: Theme.fgMuted; Layout.fillWidth: true }
                Text {
                    text: "󰐕"; color: agAdd.containsMouse ? Theme.primary : Theme.fgMuted
                    font.family: Theme.fontUi; font.pixelSize: 15
                    MouseArea { id: agAdd; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.open = false; Quickshell.execDetached(["qs", "ipc", "call", "calendar", "add"]) } }
                }
                Text {
                    text: "󰑓"; color: agRef.containsMouse ? Theme.primary : Theme.fgMuted
                    font.family: Theme.fontUi; font.pixelSize: 14
                    RotationAnimation on rotation { running: Calendars.loading; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    MouseArea { id: agRef; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Calendars.refresh(true) }
                }
            }
            Small { visible: Calendars.calendars.length === 0; text: "Noch kein Kalender – Einstellungen (SUPER+I) → Kalender"; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Small { visible: Calendars.calendars.length > 0 && ag.days.length === 0; text: Calendars.loading ? "Lade …" : "Keine Termine in den nächsten 7 Tagen" }
            Small { visible: Calendars.errors.length > 0; text: "Nicht erreichbar: " + Calendars.errors.map(e => e.cal).join(", "); color: Theme.error }
            Repeater {
                model: ag.days
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: modelData.i === 0 ? "Heute" : modelData.i === 1 ? "Morgen" : modelData.d.toLocaleDateString(Qt.locale("de_DE"), "dddd, d. MMM")
                        color: modelData.i === 0 ? Theme.primary : Theme.fgMuted
                        font.family: Theme.fontUi; font.pixelSize: 11; font.bold: true
                    }
                    Repeater {
                        model: modelData.evs
                        delegate: RowLayout {
                            required property var modelData
                            readonly property bool running: !modelData.allDay && modelData.start <= Date.now() / 1000 && modelData.end > Date.now() / 1000
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { Layout.preferredWidth: 3; Layout.preferredHeight: 28; radius: 2; color: Calendars.colorOf(modelData.cal) }
                            Text {
                                Layout.preferredWidth: 44
                                text: modelData.allDay ? "ganzt." : Qt.formatTime(new Date(modelData.start * 1000), "HH:mm")
                                color: parent.running ? Theme.primary : Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { Layout.fillWidth: true; text: modelData.title; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: parent.parent.running; elide: Text.ElideRight }
                                Small { Layout.fillWidth: true; visible: text !== ""; text: [parent.parent.running ? "läuft" : "", modelData.location ?? ""].filter(Boolean).join(" · "); elide: Text.ElideRight }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mediaW
        Card {
            readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
            Small { visible: parent.player === null; text: "󰝚  Nichts wird abgespielt" }
            Visualizer { visible: parent.player?.isPlaying ?? false; Layout.fillWidth: true; Layout.preferredHeight: 30; mirror: true }
            RowLayout {
                visible: parent.player !== null
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: 10; clip: true
                    color: Theme.surfaceContainerHighest
                    Image { anchors.fill: parent; source: parent.parent.parent.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { Layout.fillWidth: true; text: parent.parent.parent.player?.trackTitle || "Unbekannt"; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                    Small { Layout.fillWidth: true; text: parent.parent.parent.player?.trackArtist ?? ""; elide: Text.ElideRight }
                }
                IconButton { icon: "󰒮"; onClicked: parent.parent.player?.previous() }
                IconButton { icon: parent.parent.player?.isPlaying ? "󰏤" : "󰐊"; on: true; onClicked: parent.parent.player?.togglePlaying() }
                IconButton { icon: "󰒭"; onClicked: parent.parent.player?.next() }
            }
        }
    }

    Component {
        id: systemW
        Card {
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 12; columnSpacing: 12
                Meter { title: "󰻠 CPU"; value: Math.round(win.cpu * 100) + " %"; sub: Math.round(win.temp) + " °C"; hist: win.cpuHist; max: 1; warn: win.cpu > 0.85 || win.temp > 85 }
                Meter { title: "󰍛 RAM"; value: win.bytes(win.memUsed * 1024); sub: "von " + win.bytes(win.memTotal * 1024); hist: win.memHist; max: 1; warn: win.memUsed / win.memTotal > 0.9 }
                Meter { title: "󰛳 Netz"; value: "↓ " + win.rate(win.rxRate); sub: "↑ " + win.rate(win.txRate); hist: win.netHist; max: Math.max(64 * 1024, ...win.netHist) }
                ColumnLayout {
                    id: disk
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 4
                    readonly property real used: win.slow.disk.used / Math.max(1, win.slow.disk.size)
                    Small { text: "󰋊 Speicher"; color: Theme.fgMuted }
                    Text { text: win.bytes(win.slow.disk.used); color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 15; font.bold: true }
                    Small { text: "von " + win.bytes(win.slow.disk.size) + " · " + Math.round(disk.used * 100) + " %" }
                    Rectangle {
                        Layout.fillWidth: true; Layout.topMargin: 6; implicitHeight: 8; radius: 4; color: Theme.surfaceContainerHighest
                        Rectangle { width: parent.width * disk.used; height: parent.height; radius: 4; color: disk.used > 0.9 ? Theme.error : Theme.primary }
                    }
                }
            }
        }
    }

    Component {
        id: processesW
        Card {
            Small { text: "󰓅  Meiste Last gerade"; color: Theme.fgMuted }
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
    }

    Component {
        id: batteryW
        Card {
            id: batCard
            readonly property bool gentle: win.slow.bats.length > 0 && win.slow.bats.every(b => b.end > 0 && b.end <= 80)
            Small { text: "󰁹  Akkus"; color: Theme.fgMuted }
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
                        Rectangle {
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
                Button2 { text: "󰂃  Schonen (80 %)"; on: batCard.gentle; onClicked: Quickshell.execDetached(["alacritty", "--class", "floating-term", "-e", "bash", "-c", "akku schonen; akku status; read -p 'Enter zum Schließen'"]) }
                Button2 { text: "󰁹  Voll laden"; on: !batCard.gentle; onClicked: Quickshell.execDetached(["alacritty", "--class", "floating-term", "-e", "bash", "-c", "akku voll; akku status; read -p 'Enter zum Schließen'"]) }
            }
        }
    }

    // ═════════════════════════ Bausteine ═════════════════════════
    component Small: Text { color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }

    component Card: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 24
        radius: 14
        color: Theme.surfaceContainerHigh
        ColumnLayout { id: inner; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 } spacing: 8 }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon
        property string label: ""
        property string tip: ""
        property bool on: false
        property bool danger: false
        property bool enabled: true
        signal clicked()
        implicitWidth: Math.max(28, ibRow.implicitWidth + 14); implicitHeight: 28; radius: 9
        opacity: enabled ? 1 : 0.35
        color: on ? Theme.primary : (ibM.containsMouse ? (danger ? Qt.alpha(Theme.error, 0.2) : Theme.surfaceContainerHighest) : "transparent")
        Row {
            id: ibRow
            anchors.centerIn: parent
            spacing: 6
            Text { text: ib.icon; color: ib.on ? Theme.fgOnPrimary : ib.danger && ibM.containsMouse ? Theme.error : Theme.fg; font.family: Theme.fontUi; font.pixelSize: 15 }
            Text { visible: ib.label !== ""; text: ib.label; color: ib.on ? Theme.fgOnPrimary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: ibM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (ib.enabled) ib.clicked() }
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

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services

// Launcher (SUPER+R) und Wallpaper-Auswahl (SUPER+W) – ersetzt Rofi.
// Apps: unscharfe Suche, häufig genutzte zuerst. Außerdem im selben Suchfeld:
//   12*3+4 → Rechner (Enter kopiert)     :herz → Emoji (Enter kopiert)
//   >htop  → Befehl im Terminal           g suchbegriff → Websuche
//   Schnellaktionen: sperren, neustart, ausschalten, abmelden, wallpaper, einstellungen, übersicht
// Reiter „Online“: Wallpaper von wallhaven.cc suchen, Klick lädt und färbt ein.
// ↑/↓ bzw. Pfeiltasten wählen, Enter startet, Esc schließt, Tab wechselt Apps → Wallpaper → Online.
PanelWindow {
    id: win
    property bool open: false
    property string mode: "apps"          // apps | wallpapers
    property string query: ""

    visible: open || closing.running
    Timer { id: closing; interval: Theme.anim }
    onOpenChanged: {
        if (open) { query = ""; search.text = ""; list.currentIndex = 0; grid.currentIndex = 0; if (mode === "wallpapers") wallProc.running = true; search.forceActiveFocus() }
        else closing.restart()
    }
    // gleicher Modus nochmal = schließen, anderer Modus = umschalten
    function show(m) {
        if (open && mode === m) { open = false; return }
        mode = m
        open = true
        if (m === "wallpapers") wallProc.running = true
        if (m === "online") win.searchOnline(true)
    }
    // Tab: Apps → Wallpaper → Online → Apps
    function nextMode() {
        mode = mode === "apps" ? "wallpapers" : mode === "wallpapers" ? "online" : "apps"
        if (mode === "wallpapers") wallProc.running = true
        if (mode === "online") searchOnline(true)
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: mode === "apps" ? 640 : 1060
    implicitHeight: mode === "apps" ? 520 : 640

    IpcHandler {
        target: "launcher"
        function apps(): void { win.show("apps") }
        function wallpapers(): void { win.show("wallpapers") }
        function close(): void { win.open = false }
        function online(): void { win.show("online") }
        function onlineFind(q: string): void { win.mode = "online"; win.open = true; search.text = q; win.searchOnline(true) }
        // direkt mit Suchbegriff öffnen, z. B. qs ipc call launcher find ":herz"
        function find(q: string): void { win.mode = "apps"; win.open = true; search.text = q }
    }

    // ── Nutzungszähler (häufig genutzte Apps zuerst) ──────────────────────────
    property var usage: ({})
    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/launcher-usage.json"
        printErrors: false
        onLoaded: { try { win.usage = JSON.parse(text()) } catch (e) {} }
    }
    function bump(id) {
        const u = Object.assign({}, usage); u[id] = (u[id] ?? 0) + 1; usage = u
        Quickshell.execDetached(["bash", "-c", `mkdir -p ~/.cache/quickshell && printf '%s' "$1" > ~/.cache/quickshell/launcher-usage.json`, "_", JSON.stringify(u)])
    }

    // ── Emoji (einmal laden, wenn gebraucht) ──────────────────────────────────
    property var emojis: []
    FileView {
        id: emojiFile
        path: Quickshell.shellDir + "/data/emojis.tsv"
        blockLoading: true
        preload: false
    }
    // außerhalb der results-Bindung laden, sonst Bindungsschleife
    onQueryChanged: { if (query.trim().startsWith(":")) loadEmojis(); if (mode === "online") onlineDebounce.restart() }
    function loadEmojis() {
        if (emojis.length) return
        emojis = emojiFile.text().split("\n").filter(Boolean).map(l => { const [e, n, k] = l.split("\t"); return { e, n, k: (n + " " + (k ?? "")).toLowerCase() } })
    }

    // Emoji-Daten sind englisch → gängige deutsche Suchbegriffe übersetzen
    readonly property var emojiDe: ({
        herz: "heart", lachen: "laugh", lach: "laugh", lächeln: "smil", daumen: "thumbs", feuer: "fire", stern: "star",
        sonne: "sun", mond: "moon", katze: "cat", hund: "dog", auge: "eye", kuss: "kiss", weinen: "cry", traurig: "sad",
        glücklich: "happy", rakete: "rocket", haken: "check", kreuz: "cross", warnung: "warning", blume: "flower",
        baum: "tree", geld: "money", party: "party", geschenk: "gift", kaffee: "coffee", bier: "beer", essen: "food",
        auto: "car", haus: "house", wolke: "cloud", regen: "rain", schnee: "snow", blitz: "lightning", musik: "music",
        buch: "book", brief: "envelope", telefon: "phone", uhr: "clock", schloss: "lock", schlüssel: "key",
        hände: "hands", hand: "hand", winken: "wave", klatschen: "clap", denken: "think", schlafen: "sleep",
        wütend: "angry", überrascht: "surprised", cool: "cool", teufel: "devil", engel: "angel", geist: "ghost",
        totenkopf: "skull", kot: "poo", flagge: "flag", deutschland: "germany", ja: "check", nein: "cross"
    })

    // ── unscharfe Suche ───────────────────────────────────────────────────────
    function score(text, q) {
        const t = (text ?? "").toLowerCase()
        if (!q) return 1
        if (t.startsWith(q)) return 100
        if (t.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 70
        if (t.includes(q)) return 40
        let i = 0                                   // Buchstaben in Reihenfolge („ffx“ → firefox)
        for (const ch of t) if (ch === q[i]) i++
        return i === q.length ? 15 : 0
    }

    readonly property var actions: [
        { title: "Sperren", icon: "󰌾", keys: "sperren lock", run: () => Quickshell.execDetached(["loginctl", "lock-session"]) },
        { title: "Abmelden", icon: "󰍃", keys: "abmelden logout", run: () => Quickshell.execDetached(["bash", "-c", "~/.local/bin/session save; loginctl terminate-user $USER"]) },
        { title: "Neustart", icon: "󰜉", keys: "neustart reboot restart", run: () => Quickshell.execDetached(["bash", "-c", "~/.local/bin/session save; systemctl reboot"]) },
        { title: "Ausschalten", icon: "󰐥", keys: "ausschalten herunterfahren shutdown poweroff", run: () => Quickshell.execDetached(["bash", "-c", "~/.local/bin/session save; systemctl poweroff"]) },
        { title: "Ruhezustand", icon: "󰤄", keys: "ruhezustand suspend schlafen", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { title: "Wallpaper wählen", icon: "󰸉", keys: "wallpaper hintergrund farben", run: () => Qt.callLater(() => win.show("wallpapers")), keep: true },
        { title: "Einstellungen", icon: "󰒓", keys: "einstellungen settings theme schrift", run: () => Quickshell.execDetached(["qs", "ipc", "call", "settings", "toggle"]) },
        { title: "Fensterübersicht", icon: "󰕰", keys: "übersicht overview fenster", run: () => Quickshell.execDetached(["qs", "ipc", "call", "overview", "toggle"]) },
        { title: "Zwischenablage", icon: "󰅍", keys: "zwischenablage clipboard verlauf", run: () => Panels.toggle("clipboard") }
    ]

    function calc(q) {
        if (!/^[\d\s+\-*/().,%^]+$/.test(q) || !/[+\-*/%^]/.test(q)) return null
        try {
            const v = Function(`"use strict"; return (${q.replace(/,/g, ".").replace(/\^/g, "**")})`)()
            return Number.isFinite(v) ? Math.round(v * 1e10) / 1e10 : null
        } catch (e) { return null }
    }
    function copy(text, label) {
        Quickshell.execDetached(["wl-copy", text])
        Quickshell.execDetached(["notify-send", "-a", "Launcher", "-t", "1500", "Kopiert", label ?? text])
    }

    readonly property var results: {
        const raw = query.trim(), q = raw.toLowerCase()
        if (q.startsWith(":")) {                               // Emoji (geladen über onQueryChanged)
            const e = q.slice(1).trim()
            if (!e) return []
            const en = emojiDe[e] ?? Object.entries(emojiDe).find(([de]) => de.startsWith(e) && e.length >= 3)?.[1]
            return emojis.filter(x => x.k.includes(e) || (en && x.k.includes(en))).slice(0, 40)
                .map(x => ({ key: "emoji:" + x.e, glyph: x.e, emoji: true, title: x.n, sub: "Emoji · Enter kopiert", run: () => win.copy(x.e, x.e + "  " + x.n) }))
        }
        if (raw.startsWith(">")) {                             // Befehl
            const cmd = raw.slice(1).trim()
            return cmd ? [{ key: "cmd", glyph: "󰆍", title: cmd, sub: "Im Terminal ausführen", run: () => Quickshell.execDetached(["alacritty", "--hold", "-e", "bash", "-c", cmd]) }] : []
        }
        if (q.startsWith("g ") && q.length > 2) {              // Websuche
            const s = raw.slice(2).trim()
            return [{ key: "web", glyph: "󰖟", title: s, sub: "Im Web suchen", run: () => Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(s)]) }]
        }
        const out = []
        const c = calc(raw)
        if (c !== null) out.push({ key: "calc", glyph: "󰃬", title: String(c), sub: raw + "  · Enter kopiert", run: () => win.copy(String(c)) })
        const apps = DesktopEntries.applications.values
            .filter(a => !a.noDisplay)
            .map(a => ({ a, s: Math.max(score(a.name, q), score(a.genericName, q) * 0.8, score((a.keywords ?? []).join(" "), q) * 0.6) }))
            .filter(x => x.s > 0)
        // schwache Treffer (nur Buchstabenfolge) nur zeigen, wenn es keine besseren gibt
        const strong = apps.some(x => x.s >= 40)
        const appRes = apps
            .filter(x => !strong || x.s >= 40)
            .sort((x, y) => (y.s + (usage[y.a.id] ?? 0) * 3) - (x.s + (usage[x.a.id] ?? 0) * 3) || x.a.name.localeCompare(y.a.name))
            .slice(0, 30)
            .map(x => ({ key: "app:" + x.a.id, icon: x.a.icon, title: x.a.name, sub: x.a.genericName || x.a.comment || "", run: () => { win.bump(x.a.id); x.a.execute() } }))
        const acts = q ? actions.filter(x => score(x.keys, q) >= 40).map(x => ({ key: "act:" + x.title, glyph: x.icon, title: x.title, sub: "Aktion", run: x.run, keep: x.keep })) : []
        return out.concat(acts, appRes)
    }

    function activate(item) {
        if (!item) return
        if (!item.keep) open = false
        item.run()
    }

    // ── Wallpaper ─────────────────────────────────────────────────────────────
    property var walls: []
    property string currentWall: ""
    Process {
        id: wallProc
        command: [Quickshell.shellDir + "/scripts/wallpapers.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(Boolean).map(l => l.split("\t"))
                win.currentWall = rows.find(r => r[0] === "CURRENT")?.[1] ?? ""
                win.walls = rows.filter(r => r[0] !== "CURRENT").map(r => ({ path: r[0], thumb: r[1], name: r[0].split("/").pop().replace(/\.[^.]+$/, "") }))
            }
        }
    }
    readonly property var shownWalls: walls.filter(w => !query.trim() || w.name.toLowerCase().includes(query.trim().toLowerCase()))
    function applyWall(w) {
        if (!w) return
        open = false
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallthemes", w.path])
    }

    // ── Online (wallhaven.cc) ─────────────────────────────────────────────────
    property var online: []
    property int onlinePage: 1
    property int onlineLast: 1
    property string onlineQuery: ""
    property string onlineError: ""
    property string downloading: ""        // id des Bildes, das gerade lädt
    Timer { id: onlineDebounce; interval: 600; onTriggered: win.searchOnline(true) }
    function searchOnline(fresh) {
        if (onlineProc.running) return
        if (fresh) { onlinePage = 1; onlineQuery = query.trim() }
        else if (onlinePage >= onlineLast) return
        else onlinePage += 1
        onlineProc.fresh = fresh
        onlineProc.command = ["python3", "-I", Quickshell.shellDir + "/scripts/wallhaven.py", "search", onlineQuery, String(onlinePage)]
        onlineProc.running = true
    }
    Process {
        id: onlineProc
        property bool fresh: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    win.onlineError = d.error ? "wallhaven nicht erreichbar" : ""
                    win.online = onlineProc.fresh ? d.items : win.online.concat(d.items)
                    win.onlineLast = d.lastPage ?? 1
                    if (onlineProc.fresh) onlineGrid.currentIndex = 0
                } catch (e) { win.onlineError = "Antwort unlesbar" }
            }
        }
    }
    function fetchWall(w) {
        if (!w || dlProc.running) return
        downloading = w.id
        dlProc.command = ["python3", "-I", Quickshell.shellDir + "/scripts/wallhaven.py", "get", w.id, w.full]
        dlProc.running = true
    }
    Process {
        id: dlProc
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                win.downloading = ""
                if (path) { win.open = false; Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallthemes", path]) }
            }
        }
        onExited: code => { if (code !== 0) { win.downloading = ""; Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "Download fehlgeschlagen", "wallhaven.cc"]) } }
    }

    // ── Oberfläche ────────────────────────────────────────────────────────────
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 18
        color: Qt.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Theme.outlineVariant
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: [{ m: "apps", t: "󰀻  Apps" }, { m: "wallpapers", t: "󰸉  Wallpaper" }, { m: "online", t: "󰖟  Online" }]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: win.mode === modelData.m
                        implicitWidth: tabTxt.implicitWidth + 24; implicitHeight: 30; radius: 10
                        color: on ? Theme.primary : (tabMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                        Text { id: tabTxt; anchors.centerIn: parent; text: modelData.t; color: parent.on ? Theme.fgOnPrimary : Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                        MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { win.mode = modelData.m; if (modelData.m === "wallpapers") wallProc.running = true; if (modelData.m === "online") win.searchOnline(true); search.forceActiveFocus() } }
                    }
                }
                Item { Layout.fillWidth: true }
                Text { text: "Tab wechselt · Esc schließt"; color: Theme.outline; font.family: Theme.fontUi; font.pixelSize: 11 }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 12
                color: Theme.surfaceContainerHigh
                border.width: 1
                border.color: search.activeFocus ? Theme.primary : Theme.outlineVariant
                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10
                    Text { text: "󰍉"; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 16 }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.fg
                        selectionColor: Theme.primary
                        font.family: Theme.fontUi; font.pixelSize: Theme.fontPx + 2
                        onTextChanged: { win.query = text; list.currentIndex = 0; grid.currentIndex = 0 }
                        Keys.onPressed: e => {
                            const inGrid = win.mode !== "apps"
                            const g = win.mode === "online" ? onlineGrid : grid
                            if (e.key === Qt.Key_Escape) { win.open = false }
                            else if (e.key === Qt.Key_Tab) win.nextMode()
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                win.mode === "online" ? win.fetchWall(win.online[onlineGrid.currentIndex])
                                    : inGrid ? win.applyWall(win.shownWalls[grid.currentIndex]) : win.activate(win.results[list.currentIndex])
                            }
                            else if (e.key === Qt.Key_Down) inGrid ? g.moveCurrentIndexDown() : list.incrementCurrentIndex()
                            else if (e.key === Qt.Key_Up) inGrid ? g.moveCurrentIndexUp() : list.decrementCurrentIndex()
                            else if (inGrid && e.key === Qt.Key_Right && !search.text) g.moveCurrentIndexRight()
                            else if (inGrid && e.key === Qt.Key_Left && !search.text) g.moveCurrentIndexLeft()
                            else return
                            e.accepted = true
                        }
                        Text {
                            visible: !search.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.mode === "wallpapers" ? "Wallpaper suchen …" : win.mode === "online" ? "wallhaven.cc durchsuchen (leer = Toplist des Monats) …" : "Apps, 12*3, :emoji, >befehl, g websuche …"
                            color: Theme.fgMuted
                            font: search.font
                        }
                    }
                }
            }

            // Apps / Ergebnisse
            ListView {
                id: list
                visible: win.mode === "apps"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: ScriptModel { values: win.results; objectProp: "key" }   // über Schlüssel abgleichen, sonst bleiben alte Zeilen liegen
                highlightMoveDuration: 80
                highlight: Rectangle { radius: 10; color: Theme.surfaceContainerHigh; Rectangle { width: 3; height: parent.height - 14; radius: 2; color: Theme.primary; anchors { left: parent.left; verticalCenter: parent.verticalCenter } } }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 46
                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        spacing: 12
                        Item {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            IconImage { anchors.fill: parent; visible: !!row.modelData.icon; source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : "" }
                            Text { anchors.centerIn: parent; visible: !row.modelData.icon; text: row.modelData.glyph ?? ""; font.pixelSize: 20; font.family: row.modelData.emoji ? "Noto Color Emoji" : Theme.fontUi; color: Theme.primary }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: row.modelData.title; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx + 1; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { visible: text !== ""; text: row.modelData.sub ?? ""; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: list.currentIndex = row.index; onClicked: win.activate(row.modelData) }
                }
                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0 && win.query !== ""
                    text: "Nichts gefunden"
                    color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                }
            }

            // Wallpaper-Raster
            GridView {
                id: grid
                visible: win.mode === "wallpapers"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 3)
                cellHeight: cellWidth * 9 / 16 + 30
                model: ScriptModel { values: win.shownWalls }
                highlightMoveDuration: 80
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool sel: GridView.isCurrentItem
                    readonly property bool current: modelData.path === win.currentWall
                    width: grid.cellWidth
                    height: grid.cellHeight
                    ClippingRectangle {
                        id: pic
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                        height: width * 9 / 16
                        radius: 10
                        color: Theme.surfaceContainerHigh
                        border.width: cell.sel ? 3 : (cell.current ? 2 : 0)
                        border.color: cell.sel ? Theme.primary : Theme.tertiary
                        Image { anchors.fill: parent; source: "file://" + cell.modelData.thumb; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        Rectangle {
                            visible: cell.current
                            anchors { right: parent.right; top: parent.top; margins: 6 }
                            implicitWidth: curTxt.implicitWidth + 12; implicitHeight: 20; radius: 6
                            color: Theme.tertiary
                            Text { id: curTxt; anchors.centerIn: parent; text: "aktuell"; color: Theme.surface; font.family: Theme.fontUi; font.pixelSize: 11 }
                        }
                    }
                    Text {
                        anchors { top: pic.bottom; topMargin: 4; left: pic.left; right: pic.right }
                        text: cell.modelData.name
                        color: cell.sel ? Theme.primary : Theme.fgMuted
                        font.family: Theme.fontUi; font.pixelSize: 11
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: grid.currentIndex = cell.index; onClicked: win.applyWall(cell.modelData) }
                }
            }

            // Online-Raster (wallhaven.cc)
            GridView {
                id: onlineGrid
                visible: win.mode === "online"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 4)
                cellHeight: cellWidth * 9 / 16 + 28
                model: ScriptModel { values: win.online; objectProp: "id" }
                highlightMoveDuration: 80
                // beim Herunterscrollen nächste Seite laden
                onAtYEndChanged: if (atYEnd && win.online.length) win.searchOnline(false)
                delegate: Item {
                    id: oc
                    required property var modelData
                    required property int index
                    readonly property bool sel: GridView.isCurrentItem
                    readonly property bool loading: win.downloading === modelData.id
                    width: onlineGrid.cellWidth
                    height: onlineGrid.cellHeight
                    ClippingRectangle {
                        id: opic
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 5 }
                        height: width * 9 / 16
                        radius: 10
                        color: Theme.surfaceContainerHigh
                        border.width: oc.sel ? 3 : 0
                        border.color: Theme.primary
                        Image { id: oimg; anchors.fill: parent; source: oc.modelData.thumb; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        Text { anchors.centerIn: parent; visible: oimg.status !== Image.Ready && !oc.loading; text: "󰋩"; color: Theme.outline; font.family: Theme.fontUi; font.pixelSize: 22 }
                        Rectangle {
                            visible: oc.loading
                            anchors.fill: parent
                            color: Qt.alpha(Theme.scrim, 0.55)
                            Text { anchors.centerIn: parent; text: "󰇚  lädt …"; color: "white"; font.family: Theme.fontUi; font.pixelSize: 13; font.bold: true }
                        }
                    }
                    Text {
                        anchors { top: opic.bottom; topMargin: 3; left: opic.left; right: opic.right }
                        text: oc.modelData.res + "  ·  " + (oc.modelData.size / 1048576).toFixed(1) + " MB"
                        color: oc.sel ? Theme.primary : Theme.fgMuted
                        font.family: Theme.fontUi; font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: onlineGrid.currentIndex = oc.index; onClicked: win.fetchWall(oc.modelData) }
                }
                Text {
                    anchors.centerIn: parent
                    visible: onlineGrid.count === 0
                    text: win.onlineError || (onlineProc.running ? "Suche auf wallhaven.cc …" : "Nichts gefunden")
                    color: win.onlineError ? Theme.error : Theme.fgMuted
                    font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                }
            }
        }
    }
}

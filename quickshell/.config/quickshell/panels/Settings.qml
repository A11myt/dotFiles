import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Einstellungen (SUPER+I): Farben (wallthemes/Matugen) und Schrift (fontgen).
// Jede Änderung ruft das jeweilige Werkzeug auf, das die Config-Datei ändert und
// alles neu einfärbt – die Oberfläche liest danach den neuen Stand zurück.
PanelWindow {
    id: win
    property bool open: false
    property string page: "colors"

    visible: open || closing.running
    Timer { id: closing; interval: Theme.anim }
    onOpenChanged: {
        if (open) { reload(); keys.forceActiveFocus() }
        else closing.restart()
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-settings"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: 860
    implicitHeight: 600

    IpcHandler {
        target: "settings"
        function toggle(): void { win.open = !win.open }
        function open(page: string): void { win.page = page; win.open = true }
    }

    // ── Zustand der Werkzeuge ─────────────────────────────────────────────────
    property var wt: ({})          // wallthemes state
    property var fg: ({})          // fontgen state
    property var nl: ({})          // nightlight state
    property string busy: ""       // Text, solange etwas angewendet wird
    readonly property var fontProfile: (fg.profiles ?? []).find(p => p.name === fg.profile) ?? null

    function reload() { wtState.running = true; fgState.running = true; nlState.running = true }
    Process {
        id: nlState
        command: [Quickshell.env("HOME") + "/.local/bin/nightlight", "state"]
        stdout: StdioCollector { onStreamFinished: { try { win.nl = JSON.parse(text) } catch (e) {} } }
    }
    function nightlight(...args) { run("Nachtlicht wird angepasst …", [Quickshell.env("HOME") + "/.local/bin/nightlight", ...args]) }
    Process {
        id: wtState
        command: [Quickshell.env("HOME") + "/.local/bin/wallthemes", "state"]
        stdout: StdioCollector { onStreamFinished: { try { win.wt = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: fgState
        command: [Quickshell.env("HOME") + "/.local/bin/fontgen", "state"]
        stdout: StdioCollector { onStreamFinished: { try { win.fg = JSON.parse(text) } catch (e) {} } }
    }

    // Änderungen nacheinander ausführen; während eines Laufs zählt nur die letzte Anforderung
    property var pending: null
    function run(label, cmd) {
        if (runner.running) { pending = { label, cmd }; return }
        busy = label
        runner.command = cmd
        runner.running = true
    }
    Process {
        id: runner
        onExited: {
            if (win.pending) { const p = win.pending; win.pending = null; win.busy = ""; win.run(p.label, p.cmd) }
            else { win.busy = ""; win.reload() }
        }
    }
    function wallthemes(...args) { run("Farben werden angewendet …", [Quickshell.env("HOME") + "/.local/bin/wallthemes", ...args]) }
    function fontgen(...args) { run("Schrift wird angewendet …", [Quickshell.env("HOME") + "/.local/bin/fontgen", ...args]) }

    readonly property var schemeInfo: ({
        "tonal-spot": "Gedämpft, ausgewogen (Standard)",
        "vibrant": "Kräftig, satte Farben",
        "expressive": "Verspielt, Farbton verschoben",
        "fidelity": "Nah an der Bildfarbe",
        "content": "Wie fidelity, etwas ruhiger",
        "fruit-salad": "Bunt, mehrere Farbtöne",
        "rainbow": "Bunte Akzente, neutrale Flächen",
        "neutral": "Fast grau, dezente Farbe",
        "monochrome": "Schwarz-weiß"
    })
    readonly property var sourceInfo: ({
        "dominant": "häufigste Farbe", "value": "hellste Farbe", "saturation": "kräftigste Farbe",
        "lightness": "hellste Farbe (Helligkeit)", "darkness": "dunkelste Farbe", "less-saturation": "blasseste Farbe"
    })

    // ── Rahmen ────────────────────────────────────────────────────────────────
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 18
        color: Qt.alpha(Theme.surfaceContainer, 0.97)
        border.width: 1
        border.color: Theme.outlineVariant
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: win.open = false
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Seitenleiste
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 200
                color: Qt.alpha(Theme.surfaceContainerLow, 0.8)
                radius: 18
                Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 18; color: parent.color }

                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 4
                    Text {
                        text: "Einstellungen"
                        color: Theme.fg
                        font.family: Theme.fontAccent; font.pixelSize: 20
                        Layout.bottomMargin: 12; Layout.leftMargin: 6; Layout.topMargin: 4
                    }
                    Repeater {
                        model: [{ id: "colors", icon: "󰏘", t: "Farben" }, { id: "fonts", icon: "󰛖", t: "Schrift" },
                                { id: "dashboard", icon: "󰕮", t: "Dashboard" }, { id: "news", icon: "󰎕", t: "Nachrichten" },
                                { id: "bar", icon: "󰍜", t: "Leiste" }, { id: "focus", icon: "󱎫", t: "Fokus" },
                                { id: "calendar", icon: "󰃭", t: "Kalender" }]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool on: win.page === modelData.id
                            Layout.fillWidth: true
                            implicitHeight: 40; radius: 12
                            color: on ? Theme.primary : (navMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                            Row {
                                anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
                                spacing: 12
                                Text { text: modelData.icon; color: on ? Theme.fgOnPrimary : Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 16 }
                                Text { text: modelData.t; color: on ? Theme.fgOnPrimary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx + 1 }
                            }
                            MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.page = modelData.id }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    // Status
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        visible: win.busy !== ""
                        spacing: 8
                        Text {
                            text: "󰑓"; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 14
                            RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: win.busy !== "" }
                        }
                        Text { Layout.fillWidth: true; text: win.busy; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; wrapMode: Text.WordWrap }
                    }
                    Text { Layout.leftMargin: 6; text: "Esc schließt"; color: Theme.outline; font.family: Theme.fontUi; font.pixelSize: 11 }
                }
            }

            // Inhalt
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: content.implicitHeight + 48
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: content
                    x: 28; y: 24
                    width: parent.width - 56
                    spacing: 22

                    // ═════════════ Farben ═════════════
                    ColumnLayout {
                        visible: win.page === "colors"
                        Layout.fillWidth: true
                        spacing: 22

                        Section { title: "Ausgangsfarbe"; sub: "Matugen zieht 4 Farben aus dem Wallpaper. Die Wahl gilt nur für dieses Bild." }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            ClippingRectangle {
                                Layout.preferredWidth: 220; Layout.preferredHeight: 124
                                radius: 12
                                color: Theme.surfaceContainerHigh
                                Image { anchors.fill: parent; source: win.wt.image ? "file://" + win.wt.image : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 440 }
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                rowSpacing: 10; columnSpacing: 10
                                Swatch {
                                    label: "Automatisch"
                                    sub: win.sourceInfo[win.wt.source] ?? ""
                                    selected: win.wt.pick === null || win.wt.pick === undefined
                                    onClicked: win.wallthemes("pick", "auto")
                                }
                                Repeater {
                                    model: win.wt.colors ?? []
                                    delegate: Swatch {
                                        required property var modelData
                                        required property int index
                                        swatch: modelData
                                        label: "Farbe " + (index + 1)
                                        sub: modelData
                                        selected: win.wt.pick === index
                                        onClicked: win.wallthemes("pick", String(index))
                                    }
                                }
                            }
                        }

                        Section {
                            title: "Modus"
                            sub: win.wt.auto ? `Automatisch: hell von ${win.wt.sunrise} bis ${win.wt.sunset} Uhr. Ein Wechsel von Hand gilt bis zum nächsten Sonnenauf-/-untergang.`
                                             : "Automatisch wechselt nach Sonnenauf- und -untergang"
                        }
                        RowLayout {
                            spacing: 10
                            Repeater {
                                model: [{ m: "dark", t: "󰖔  Dunkel" }, { m: "light", t: "󰖨  Hell" }]
                                delegate: Chip {
                                    required property var modelData
                                    text: modelData.t
                                    selected: win.wt.mode === modelData.m
                                    onClicked: if (!selected) win.wallthemes("set", "mode", modelData.m)
                                }
                            }
                            Rectangle { implicitWidth: 1; implicitHeight: 22; color: Theme.outlineVariant }
                            Chip {
                                text: "󰖛  Automatisch"
                                selected: win.wt.auto ?? false
                                onClicked: win.wallthemes("auto", selected ? "off" : "on")
                            }
                        }

                        Section {
                            title: "Nachtlicht"
                            sub: !win.nl.installed ? "hyprsunset ist nicht installiert: sudo pacman -S hyprsunset"
                               : win.nl.enabled ? `Automatisch wärmer ab ${win.nl.from} Uhr bis nach Sonnenaufgang (${win.nl.to} Uhr), sanfter Übergang`
                               : "Aus – kein Blaulichtfilter"
                        }
                        RowLayout {
                            spacing: 10
                            Chip { text: "󰖛  Automatisch"; selected: win.nl.enabled ?? false; onClicked: win.nightlight(selected ? "disable" : "auto") }
                            Rectangle { implicitWidth: 1; implicitHeight: 22; color: Theme.outlineVariant }
                            Repeater {
                                model: [{ k: 3000, t: "sehr warm" }, { k: 3500, t: "warm" }, { k: 4000, t: "mittel" }, { k: 4500, t: "leicht" }, { k: 5000, t: "dezent" }]
                                delegate: Chip {
                                    required property var modelData
                                    text: modelData.t
                                    selected: win.nl.night_temp === modelData.k
                                    onClicked: if (!selected) win.nightlight("temp", String(modelData.k))
                                }
                            }
                        }

                        Section { title: "Farbschema"; sub: "Wie Matugen aus der Ausgangsfarbe die Palette baut" }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: 8; columnSpacing: 8
                            Repeater {
                                model: win.wt.schemes ?? []
                                delegate: Rectangle {
                                    id: sch
                                    required property string modelData
                                    readonly property bool sel: win.wt.scheme === modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 54; radius: 12
                                    color: sel ? Theme.primaryContainer : (schMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                    border.width: sel ? 2 : 0
                                    border.color: Theme.primary
                                    ColumnLayout {
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 8; bottomMargin: 8 }
                                        spacing: 1
                                        Text { text: sch.modelData; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; font.bold: sch.sel }
                                        Text { Layout.fillWidth: true; text: win.schemeInfo[sch.modelData] ?? ""; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight }
                                    }
                                    MouseArea { id: schMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!sch.sel) win.wallthemes("set", "scheme", sch.modelData) }
                                }
                            }
                        }

                        Section { title: "Kontrast"; sub: "Mitte = wie von Material vorgesehen" }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            Text { text: "weniger"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }
                            ThemeSlider {
                                id: contrast
                                Layout.fillWidth: true
                                property real shown: ((win.wt.contrast ?? 0) + 1) / 2
                                value: shown
                                onMoved: v => { value = Math.round(v * 8) / 8; commit.restart() }
                                Timer {   // erst anwenden, wenn der Regler losgelassen/ruhig ist
                                    id: commit
                                    interval: 500
                                    onTriggered: win.wallthemes("set", "contrast", (contrast.value * 2 - 1).toFixed(2))
                                }
                                Connections { target: win; function onWtChanged() { contrast.value = contrast.shown } }
                            }
                            Text { text: "mehr"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }
                        }

                        Section { title: "Automatische Ausgangsfarbe"; sub: "Gilt für alle Wallpaper ohne eigene Wahl" }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: win.wt.sources ?? []
                                delegate: Chip {
                                    required property string modelData
                                    text: win.sourceInfo[modelData] ?? modelData
                                    selected: win.wt.source === modelData
                                    onClicked: if (!selected) win.wallthemes("set", "source", modelData)
                                }
                            }
                        }
                    }

                    // ═════════════ Dashboard ═════════════
                    ColumnLayout {
                        visible: win.page === "dashboard"
                        Layout.fillWidth: true
                        spacing: 22
                        Section { title: "Widgets"; sub: "Info-Leiste rechts (SUPER+B). Reihenfolge änderst du dort über den Stift." }
                        ColumnLayout { Layout.fillWidth: true; spacing: 8; Repeater {
                            model: Object.keys(Config.widgetInfo)
                            delegate: SwitchRow {
                                required property string modelData
                                readonly property var info: Config.widgetInfo[modelData]
                                icon: info.icon; title: info.name; sub: info.desc
                                checked: Config.widgets.indexOf(modelData) >= 0
                                onToggled: on => Config.set("widgets", on ? Config.widgets.concat([modelData]) : Config.widgets.filter(w => w !== modelData))
                            }
                        } }
                    }

                    // ═════════════ Nachrichten ═════════════
                    ColumnLayout {
                        visible: win.page === "news"
                        Layout.fillWidth: true
                        spacing: 22
                        Section { title: "Quellen"; sub: "RSS- oder Atom-Feeds. Neue Schlagzeilen werden alle 15 Minuten geholt." }
                        ColumnLayout { Layout.fillWidth: true; spacing: 8; Repeater {
                            model: Config.feeds
                            delegate: Rectangle {
                                id: feed
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 50; radius: 12
                                color: Theme.surfaceContainerHigh
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 14; rightMargin: 8 }
                                    spacing: 10
                                    Text { text: "󰑫"; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 18 }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 0
                                        Text { text: feed.modelData.name; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; font.bold: true }
                                        Text { Layout.fillWidth: true; text: feed.modelData.url; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideMiddle }
                                    }
                                    Chip { text: "󰅖"; onClicked: Config.set("feeds", Config.feeds.filter((_, i) => i !== feed.index)) }
                                }
                            }
                        } }
                        // neue Quelle
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Field { id: feedName; Layout.preferredWidth: 150; placeholder: "Name" }
                            Field { id: feedUrl; Layout.fillWidth: true; placeholder: "https://…/feed.xml"; onAccepted: addFeed.clicked() }
                            Chip {
                                id: addFeed
                                text: "󰐕  Hinzufügen"
                                selected: true
                                onClicked: {
                                    const url = feedUrl.text.trim()
                                    if (!/^https?:\/\//.test(url)) return
                                    const name = feedName.text.trim() || url.replace(/^https?:\/\/(www\.)?/, "").split(/[\/.]/)[0]
                                    Config.set("feeds", Config.feeds.concat([{ name, url }]))
                                    feedName.text = ""; feedUrl.text = ""
                                }
                            }
                        }
                        Section { title: "Vorschläge"; sub: "Antippen zum Hinzufügen" }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: [
                                    { name: "tagesschau", url: "https://www.tagesschau.de/index~rss2.xml" },
                                    { name: "heise", url: "https://www.heise.de/rss/heise-top-atom.xml" },
                                    { name: "Spiegel", url: "https://www.spiegel.de/schlagzeilen/index.rss" },
                                    { name: "Zeit", url: "https://newsfeed.zeit.de/index" },
                                    { name: "golem", url: "https://rss.golem.de/rss.php?feed=ATOM1.0" },
                                    { name: "t3n", url: "https://t3n.de/rss.xml" },
                                    { name: "Arch Linux", url: "https://archlinux.org/feeds/news/" },
                                    { name: "Hacker News", url: "https://hnrss.org/frontpage" },
                                    { name: "kicker", url: "https://newsfeed.kicker.de/news/aktuell" }
                                ].filter(f => !Config.feeds.some(x => x.url === f.url))
                                delegate: Chip {
                                    required property var modelData
                                    text: "󰐕  " + modelData.name
                                    onClicked: Config.set("feeds", Config.feeds.concat([modelData]))
                                }
                            }
                        }
                        Section { title: "Anzahl"; sub: "Schlagzeilen im Dashboard (mit „mehr anzeigen“ dreimal so viele)" }
                        RowLayout {
                            spacing: 8
                            Repeater {
                                model: [3, 5, 6, 8, 10]
                                delegate: Chip { required property int modelData; text: String(modelData); selected: Config.newsCount === modelData; onClicked: Config.set("newsCount", modelData) }
                            }
                        }
                        RowLayout {
                            visible: Config.newsHidden.length > 0
                            spacing: 10
                            Text { text: Config.newsHidden.length + " Schlagzeilen ausgeblendet"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12 }
                            Chip { text: "Wieder anzeigen"; onClicked: Config.set("newsHidden", []) }
                        }
                    }

                    // ═════════════ Leiste ═════════════
                    ColumnLayout {
                        visible: win.page === "bar"
                        Layout.fillWidth: true
                        spacing: 22
                        Section { title: "Elemente der Leiste"; sub: "Ausgeblendetes bleibt über Quick Settings und Dashboard erreichbar" }
                        ColumnLayout { Layout.fillWidth: true; spacing: 8; Repeater {
                            model: Object.keys(Config.barInfo)
                            delegate: SwitchRow {
                                required property string modelData
                                title: Config.barInfo[modelData]
                                checked: Config.barOn(modelData)
                                onToggled: on => Config.setBar(modelData, on)
                            }
                        } }
                    }

                    // ═════════════ Fokus ═════════════
                    ColumnLayout {
                        visible: win.page === "focus"
                        Layout.fillWidth: true
                        spacing: 22
                        Section { title: "Fokus-Timer"; sub: "In der Leiste: Klick startet/pausiert, Rechtsklick stoppt, Mittelklick überspringt. SUPER+Shift+P startet." }
                        Repeater {
                            model: [
                                { k: "work", t: "Fokus", opts: [15, 20, 25, 30, 45, 50, 60], unit: " min" },
                                { k: "short", t: "Kurze Pause", opts: [3, 5, 10], unit: " min" },
                                { k: "long", t: "Lange Pause", opts: [10, 15, 20, 30], unit: " min" },
                                { k: "rounds", t: "Lange Pause nach", opts: [2, 3, 4, 5, 6], unit: " Runden" }
                            ]
                            delegate: RowLayout {
                                id: fr
                                required property var modelData
                                spacing: 8
                                Text { Layout.preferredWidth: 140; text: fr.modelData.t; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                                Repeater {
                                    model: fr.modelData.opts
                                    delegate: Chip {
                                        required property int modelData
                                        text: modelData + fr.modelData.unit
                                        selected: Config.focus[fr.modelData.k] === modelData
                                        onClicked: Config.setFocus(fr.modelData.k, modelData)
                                    }
                                }
                            }
                        }
                        SwitchRow {
                            icon: "󰂛"
                            title: "„Nicht stören“ während Fokus"
                            sub: "Benachrichtigungen bleiben in der Zentrale, Popups erst in der Pause"
                            checked: Config.focus.dnd
                            onToggled: on => Config.setFocus("dnd", on)
                        }
                    }

                    // ═════════════ Kalender ═════════════
                    ColumnLayout {
                        visible: win.page === "calendar"
                        Layout.fillWidth: true
                        spacing: 22
                        Section {
                            title: "Kalender"
                            sub: "iCal-Adressen (.ics). Google: calendar.google.com → Einstellungen → dein Kalender → „Privatadresse im iCal-Format“ kopieren. Die Adresse ist geheim und wird nur lokal gespeichert (nicht in den Dotfiles)."
                        }
                        ColumnLayout { Layout.fillWidth: true; spacing: 8; Repeater {
                            model: Calendars.calendars
                            delegate: Rectangle {
                                id: calRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 50; radius: 12
                                color: Theme.surfaceContainerHigh
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 14; rightMargin: 8 }
                                    spacing: 10
                                    Rectangle { width: 12; height: 12; radius: 6; color: Calendars.colorOf(calRow.modelData.name) }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 0
                                        Text { text: calRow.modelData.name; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; font.bold: true }
                                        // nur Anfang der Adresse zeigen (geheim)
                                        Text { Layout.fillWidth: true; text: calRow.modelData.url.replace(/^(https?:\/\/[^/]+\/).*$/, "$1…") + "  ·  " + Calendars.events.filter(e => e.cal === calRow.modelData.name).length + " Termine"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight }
                                    }
                                    Chip { text: "󰅖"; onClicked: Calendars.remove(calRow.index) }
                                }
                            }
                        } }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Field { id: calName; Layout.preferredWidth: 140; placeholder: "Name" }
                            Field { id: calUrl; Layout.fillWidth: true; placeholder: "https://…/basic.ics"; secret: true; onAccepted: addCal.clicked() }
                            Chip {
                                id: addCal
                                text: "󰐕  Hinzufügen"
                                selected: true
                                onClicked: {
                                    const url = calUrl.text.trim()
                                    if (!/^(https?|webcal):\/\//.test(url)) return
                                    Calendars.add(calName.text.trim() || "Kalender " + (Calendars.calendars.length + 1), url)
                                    calName.text = ""; calUrl.text = ""
                                }
                            }
                        }
                        Text {
                            visible: Calendars.errors.length > 0
                            text: "Nicht erreichbar: " + Calendars.errors.map(e => e.cal + " (" + e.error + ")").join(", ")
                            color: Theme.error; font.family: Theme.fontUi; font.pixelSize: 12
                        }
                        Text {
                            visible: Calendars.calendars.length > 0
                            text: Calendars.loading ? "Lade Termine …" : Calendars.events.length + " Termine geladen (5 Wochen zurück bis 10 Wochen voraus)"
                            color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12
                        }
                    }

                    // ═════════════ Schrift ═════════════
                    ColumnLayout {
                        visible: win.page === "fonts"
                        Layout.fillWidth: true
                        spacing: 22

                        Section { title: "Schriftprofil"; sub: "Gilt für Leiste, GTK/Qt-Apps, Terminal, Editor und Sperrbildschirm" }
                        Repeater {
                            model: win.fg.profiles ?? []
                            delegate: Rectangle {
                                id: prof
                                required property var modelData
                                readonly property bool sel: win.fg.profile === modelData.name
                                Layout.fillWidth: true
                                implicitHeight: profCol.implicitHeight + 24
                                radius: 14
                                color: sel ? Theme.primaryContainer : (profMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                border.width: sel ? 2 : 0
                                border.color: Theme.primary
                                opacity: modelData.installed ? 1 : 0.5
                                ColumnLayout {
                                    id: profCol
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                                    spacing: 4
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: prof.modelData.name; color: Theme.fg; font.family: prof.modelData.accent; font.pixelSize: 18 }
                                        Item { Layout.fillWidth: true }
                                        Text { visible: !prof.modelData.installed; text: "nicht installiert"; color: Theme.error; font.family: Theme.fontUi; font.pixelSize: 11 }
                                        Text { visible: prof.sel; text: "󰄬 aktiv"; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 12 }
                                    }
                                    Text { text: "Oberfläche: Franz jagt im komplett verwahrlosten Taxi quer durch Bayern"; color: Theme.fg; font.family: prof.modelData.ui; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: "Code: fn main() { let x = 0x1F; } // il1| O0 => != ->"; color: Theme.fgMuted; font.family: prof.modelData.mono; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                MouseArea {
                                    id: profMouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (!prof.sel && prof.modelData.installed) win.fontgen("use", prof.modelData.name)
                                }
                            }
                        }

                        Section { title: "Größe"; sub: "In Punkt, für das aktive Profil" }
                        Repeater {
                            model: [{ k: "ui", t: "Oberfläche" }, { k: "mono", t: "Terminal & Code" }]
                            delegate: RowLayout {
                                id: sz
                                required property var modelData
                                readonly property real val: win.fontProfile ? win.fontProfile[modelData.k + "_size"] : 10
                                Layout.fillWidth: true
                                spacing: 12
                                Text { Layout.preferredWidth: 150; text: sz.modelData.t; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                                Chip { text: "−"; onClicked: sz.change(-0.5) }
                                Text { Layout.preferredWidth: 60; horizontalAlignment: Text.AlignHCenter; text: sz.val + " pt"; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx + 2 }
                                Chip { text: "+"; onClicked: sz.change(0.5) }
                                function change(d) {
                                    const p = win.fontProfile
                                    if (!p) return
                                    const ui = sz.modelData.k === "ui" ? p.ui_size + d : p.ui_size
                                    const mono = sz.modelData.k === "mono" ? p.mono_size + d : p.mono_size
                                    // sofort anzeigen, fontgen übernimmt im Hintergrund
                                    win.fg = Object.assign({}, win.fg, { profiles: win.fg.profiles.map(x => x.name === p.name ? Object.assign({}, x, { ui_size: ui, mono_size: mono }) : x) })
                                    win.fontgen("size", String(ui), String(mono))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── kleine Bausteine ──────────────────────────────────────────────────────
    component Section: ColumnLayout {
        property string title
        property string sub: ""
        Layout.fillWidth: true
        Layout.bottomMargin: -10
        spacing: 2
        Text { text: parent.title; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx + 3; font.bold: true }
        Text { visible: text !== ""; text: parent.sub; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    }

    component SwitchRow: Rectangle {
        id: sr
        property string icon: ""
        property string title
        property string sub: ""
        property bool checked
        signal toggled(bool on)
        Layout.fillWidth: true
        implicitHeight: sub ? 52 : 44; radius: 12
        color: srM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        MouseArea { id: srM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sr.toggled(!sr.checked) }
        RowLayout {
            anchors { left: parent.left; right: toggle.left; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 12 }
            spacing: 12
            Text { visible: sr.icon !== ""; text: sr.icon; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 18 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { Layout.fillWidth: true; text: sr.title; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                Text { Layout.fillWidth: true; visible: sr.sub !== ""; text: sr.sub; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }
            }
        }
        // fest am rechten Rand, damit alle Schalter bündig stehen
        Toggle { id: toggle; anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } checked: sr.checked; onToggled: on => sr.toggled(on) }
    }

    component Field: Rectangle {
        id: fld
        property alias text: inp.text
        property string placeholder
        property bool secret: false
        signal accepted()
        implicitHeight: 36; radius: 10
        color: Theme.surfaceContainerHigh
        border.width: 1; border.color: inp.activeFocus ? Theme.primary : Theme.outlineVariant
        TextInput {
            id: inp
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12
            echoMode: fld.secret && !activeFocus ? TextInput.Password : TextInput.Normal
            onAccepted: fld.accepted()
            Text { visible: !inp.text; anchors.verticalCenter: parent.verticalCenter; text: fld.placeholder; color: Theme.fgMuted; font: inp.font }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: inp.forceActiveFocus(); propagateComposedEvents: true }
    }

    component Chip: Rectangle {
        id: chip
        property string text
        property bool selected: false
        signal clicked()
        implicitWidth: chipTxt.implicitWidth + 28
        implicitHeight: 34
        radius: 10
        color: selected ? Theme.primary : (chipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
        Text { id: chipTxt; anchors.centerIn: parent; text: chip.text; color: chip.selected ? Theme.fgOnPrimary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }

    component Swatch: Rectangle {
        id: sw
        property string swatch: ""
        property string label
        property string sub: ""
        property bool selected: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 56
        radius: 12
        color: selected ? Theme.primaryContainer : (swMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
        border.width: selected ? 2 : 0
        border.color: Theme.primary
        RowLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                color: sw.swatch || "transparent"
                border.width: sw.swatch ? 1 : 2
                border.color: sw.swatch ? Qt.alpha(Theme.fg, 0.3) : Theme.outline
                Text { visible: !sw.swatch; anchors.centerIn: parent; text: "󰁨"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 15 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { text: sw.label; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; font.bold: sw.selected }
                Text { Layout.fillWidth: true; text: sw.sub; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight }
            }
        }
        MouseArea { id: swMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sw.clicked() }
    }
}

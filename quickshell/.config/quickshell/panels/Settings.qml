import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components

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
    property string busy: ""       // Text, solange etwas angewendet wird
    readonly property var fontProfile: (fg.profiles ?? []).find(p => p.name === fg.profile) ?? null

    function reload() { wtState.running = true; fgState.running = true }
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
                        model: [{ id: "colors", icon: "󰏘", t: "Farben" }, { id: "fonts", icon: "󰛖", t: "Schrift" }]
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

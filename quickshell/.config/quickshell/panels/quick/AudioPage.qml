import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

// Audio-Unterseite: Ausgabegerät, Mikrofon und Lautstärke pro App (ersetzt meist pavucontrol)
ColumnLayout {
    id: page
    property bool active: false
    spacing: 8

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream && !(n.name ?? "").endsWith(".monitor"))
    readonly property var streams: nodes.filter(n => n.isStream && n.type === PwNodeType.AudioOutStream)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // ── Profile der Soundkarten (pactl): Bluetooth Hi-Fi/Headset, HDMI … ──
    property var cards: []
    onActiveChanged: if (active) cardsProc.running = true
    // Geräte kommen/gehen (Kopfhörer, HDMI) → Karten neu lesen
    onSinksChanged: if (active) cardsTimer.restart()
    Timer { id: cardsTimer; interval: 800; onTriggered: cardsProc.running = true }
    Process {
        id: cardsProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.cards = JSON.parse(text).map(c => ({
                        name: c.name,
                        label: c.properties?.["device.description"] ?? c.name,
                        bt: c.name.startsWith("bluez"),
                        active: c.active_profile,
                        profiles: Object.entries(c.profiles).filter(([k, v]) => v.available && page.usefulProfile(c.name, k))
                                        .sort((a, b) => b[1].priority - a[1].priority)
                                        .map(([k, v]) => ({ id: k, label: page.profileLabel(k, v.description) }))
                    })).filter(c => c.profiles.length > 1)
                } catch (e) { page.cards = [] }
            }
        }
    }
    // Bluetooth: alle Profile außer „aus“; eingebaute Karte: nur Stereo+Mikro gegen HDMI+Mikro
    // (Surround/Pro Audio/Nur-Eingang braucht man praktisch nie → bleibt im pavucontrol)
    function usefulProfile(card, id) {
        if (id === "off") return false
        if (card.startsWith("bluez")) return true
        return id === "output:analog-stereo+input:analog-stereo" || /^output:hdmi-stereo(-extra\d)?\+input:analog-stereo$/.test(id)
    }
    function profileLabel(id, desc) {
        if (id.startsWith("a2dp")) return "Hi-Fi" + (desc.match(/\(([^)]+)\)/) ? " · " + desc.match(/\(([^)]+)\)/)[1] : "")
        if (id.startsWith("headset") || id.includes("hfp") || id.includes("hsp")) return "Headset mit Mikro"
        if (id.startsWith("output:analog")) return "Lautsprecher / Klinke"
        const hdmi = id.match(/hdmi-stereo(?:-extra(\d))?/)
        if (hdmi) return "HDMI" + (hdmi[1] ? " " + (Number(hdmi[1]) + 1) : "")
        return desc
    }
    Process { id: setProfile; onExited: cardsTimer.restart() }
    function chooseProfile(card, prof) {
        setProfile.command = ["pactl", "set-card-profile", card, prof]
        setProfile.running = true
    }

    // Lautstärke/Eigenschaften werden nur für verfolgte Knoten aktualisiert
    PwObjectTracker { objects: page.active ? page.nodes : [] }

    function label(n) { return n?.nickname || n?.description || n?.name || "?" }
    function sinkIcon(n) {
        const s = ((n?.name ?? "") + " " + (n?.description ?? "")).toLowerCase()
        return s.includes("bluez") || s.includes("headphone") || s.includes("headset") ? "󰋋" : s.includes("hdmi") || s.includes("displayport") ? "󰡁" : "󰓃"
    }

    PageHeader { title: "Audio"; hasToggle: false }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 440)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6

            // ── Ausgabe ──
            SectionLabel { text: "Ausgabe" }
            Text { visible: page.sinks.length <= 1; Layout.leftMargin: 4; text: page.label(page.sink); color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            VolumeRow { node: page.sink; icon: page.sinkIcon(page.sink); mutedIcon: "󰝟" }
            Repeater {
                model: page.sinks
                delegate: ListRow {
                    required property var modelData
                    visible: page.sinks.length > 1
                    icon: page.sinkIcon(modelData)
                    title: page.label(modelData)
                    active: modelData === page.sink
                    trailing: active ? "󰄬" : ""
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            // ── Profile ──
            Repeater {
                model: page.cards
                delegate: ColumnLayout {
                    id: card
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 4
                    Text {
                        Layout.leftMargin: 4
                        text: (card.modelData.bt ? "󰂯  " : "󰓃  ") + card.modelData.label
                        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: card.modelData.profiles
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: modelData.id === card.modelData.active
                                implicitWidth: profTxt.implicitWidth + 20; implicitHeight: 28; radius: 9
                                color: sel ? Theme.primary : (profMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                Text { id: profTxt; anchors.centerIn: parent; text: modelData.label; color: parent.sel ? Theme.fgOnPrimary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: 11 }
                                MouseArea { id: profMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!parent.sel) page.chooseProfile(card.modelData.name, modelData.id) }
                            }
                        }
                    }
                }
            }

            // ── Mikrofon ──
            SectionLabel { text: "Mikrofon"; Layout.topMargin: 6; visible: page.sources.length > 0 }
            VolumeRow { visible: page.source !== null; node: page.source; icon: "󰍬"; mutedIcon: "󰍭" }
            Repeater {
                model: page.sources
                delegate: ListRow {
                    required property var modelData
                    visible: page.sources.length > 1
                    icon: "󰍬"
                    title: page.label(modelData)
                    active: modelData === page.source
                    trailing: active ? "󰄬" : ""
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }

            // ── Apps ──
            SectionLabel { text: "Apps"; Layout.topMargin: 6 }
            Repeater {
                model: page.streams
                delegate: ColumnLayout {
                    id: app
                    required property var modelData
                    readonly property var props: modelData.properties ?? {}
                    readonly property string appName: props["application.name"] || page.label(modelData)
                    readonly property var entry: DesktopEntries.heuristicLookup(props["application.process.binary"] || appName)
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        spacing: 8
                        IconImage {
                            implicitSize: 18
                            source: Quickshell.iconPath(app.props["application.icon-name"] || app.entry?.icon || "", "audio-x-generic")
                        }
                        Text { text: app.entry?.name || app.appName; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: true }
                        Text { Layout.fillWidth: true; text: app.props["media.name"] ?? ""; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight }
                    }
                    VolumeRow { node: app.modelData; icon: "󰕾"; mutedIcon: "󰝟" }
                }
            }
            Text {
                visible: page.streams.length === 0
                Layout.leftMargin: 4
                text: "Keine App spielt gerade etwas ab"
                color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11
            }
        }
    }

    ActionButton {
        text: "󰒓  Erweiterter Mixer (pavucontrol)"
        onClicked: { Panels.close(); Quickshell.execDetached(["pavucontrol"]) }
    }

    component SectionLabel: Text {
        Layout.leftMargin: 4
        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; font.bold: true
        font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8
    }

    // Stummschalten + Regler + Prozent für einen Knoten
    component VolumeRow: RowLayout {
        id: vr
        property var node
        property string icon
        property string mutedIcon
        readonly property bool muted: node?.audio?.muted ?? false
        readonly property real vol: node?.audio?.volume ?? 0
        Layout.fillWidth: true
        spacing: 10
        Text {
            text: vr.muted ? vr.mutedIcon : vr.icon
            color: vr.muted ? Theme.fgMuted : Theme.primary
            font.family: Theme.fontUi; font.pixelSize: 17
            Layout.preferredWidth: 24
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (vr.node?.audio) vr.node.audio.muted = !vr.muted }
        }
        ThemeSlider {
            Layout.fillWidth: true
            opacity: vr.muted ? 0.5 : 1
            value: vr.vol
            onMoved: v => { if (vr.node?.audio) vr.node.audio.volume = v }
        }
        Text {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round(vr.vol * 100) + "%"
            color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11
        }
    }
}

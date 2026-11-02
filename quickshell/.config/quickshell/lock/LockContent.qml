import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import qs

// Oberfläche des Sperrbildschirms (pro Bildschirm): unscharfes Wallpaper, Uhr, Datum,
// Wetter, Akku, Medien, Passwortfeld. Tasteneingabe geht an lock.type().
Item {
    id: content
    required property var lock

    Component.onCompleted: keys.forceActiveFocus()

    // ── Hintergrund ──
    Process {
        id: wallProc
        command: ["readlink", "-e", Quickshell.env("HOME") + "/.cache/wallpaper-picker/current"]
        running: true
        stdout: StdioCollector { onStreamFinished: bg.source = text.trim() ? "file://" + text.trim() : "" }
    }
    Image {
        id: bg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: content.width / 2      // halbe Auflösung reicht für Unschärfe, spart Zeit
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: bg
        source: bg
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        saturation: 0.1
    }
    Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.scrim, 0.35) }

    // ── Eingabe ──
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => { content.lock.type(e); e.accepted = true }
        MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ── Uhr & Datum ──
    ColumnLayout {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.14 }
        spacing: 4
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            color: Theme.fg
            font.family: Theme.fontAccent
            font.pixelSize: Math.min(160, content.height * 0.15)
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: clock.date.toLocaleDateString(Qt.locale("de_DE"), "dddd, d. MMMM")
            color: Theme.fg
            opacity: 0.85
            font.family: Theme.fontUi
            font.pixelSize: 22
        }
        // Wetter (Cache der Leiste) und Akku
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            spacing: 18
            Text {
                visible: text !== ""
                text: content.weather
                color: Theme.fg; opacity: 0.8
                font.family: Theme.fontUi; font.pixelSize: 15
            }
            Text {
                readonly property var dev: UPower.displayDevice
                visible: dev?.isLaptopBattery ?? false
                text: (dev?.state === UPowerDeviceState.Charging ? "󰂄 " : "󰁹 ") + Math.round((dev?.percentage ?? 0) * 100) + " %"
                color: (dev?.percentage ?? 1) <= 0.15 ? Theme.error : Theme.fg
                opacity: 0.8
                font.family: Theme.fontUi; font.pixelSize: 15
            }
        }
    }
    property string weather: ""
    FileView {
        path: "/tmp/qs-weather.json"
        printErrors: false
        onLoaded: { try { const j = JSON.parse(text()); content.weather = (j.text ?? "").trim() } catch (e) {} }
    }

    // ── Passwort ──
    ColumnLayout {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.verticalCenter; topMargin: parent.height * 0.12 }
        spacing: 12

        Rectangle {
            id: field
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 340
            implicitHeight: 56
            radius: 28
            color: Qt.alpha(Theme.surfaceContainer, 0.85)
            border.width: 2
            border.color: content.lock.failed ? Theme.error : content.lock.busy ? Theme.tertiary : Theme.primary

            // Wackeln bei falschem Passwort
            transform: Translate { id: shakeT }
            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: shakeT; property: "x"; to: -10; duration: 45 }
                NumberAnimation { target: shakeT; property: "x"; to: 10; duration: 90 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 45 }
            }
            Connections { target: content.lock; function onFailedChanged() { if (content.lock.failed) shake.restart() } }

            Text {
                anchors.centerIn: parent
                visible: content.lock.buffer.length === 0
                text: content.lock.busy ? "Prüfe …" : content.lock.preview ? "Vorschau – Enter/Esc schließt" : "Passwort eingeben"
                color: Theme.fgMuted
                font.family: Theme.fontUi; font.pixelSize: 15
            }
            Row {
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: Math.min(content.lock.buffer.length, 20)
                    delegate: Rectangle { width: 10; height: 10; radius: 5; color: Theme.primary }
                }
            }
            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: "󰌾"; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 20
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: text !== ""
            text: content.lock.message
            color: Theme.error
            font.family: Theme.fontUi; font.pixelSize: 14
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Quickshell.env("USER")
            color: Theme.fg; opacity: 0.6
            font.family: Theme.fontUi; font.pixelSize: 13
        }
    }

    // ── Medien ──
    Rectangle {
        id: media
        readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
        visible: player !== null
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
        implicitWidth: Math.min(520, mediaRow.implicitWidth + 28)
        implicitHeight: 64
        radius: 18
        color: Qt.alpha(Theme.surfaceContainer, 0.8)
        RowLayout {
            id: mediaRow
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 12
            ColumnLayout {
                spacing: 0
                Layout.maximumWidth: 360
                Text { Layout.fillWidth: true; text: media.player?.trackTitle || "Unbekannt"; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: media.player?.trackArtist ?? ""; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12; elide: Text.ElideRight }
            }
            Repeater {
                model: [{ i: "󰒮", a: "previous" }, { i: "play", a: "togglePlaying" }, { i: "󰒭", a: "next" }]
                delegate: Text {
                    required property var modelData
                    readonly property var player: media.player
                    text: modelData.i === "play" ? (player?.isPlaying ? "󰏤" : "󰐊") : modelData.i
                    color: mm.containsMouse ? Theme.primary : Theme.fg
                    font.family: Theme.fontUi; font.pixelSize: 22
                    MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: { player?.[modelData.a](); keys.forceActiveFocus() } }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services

// Medien-Popup (Klick auf den Titel in der Leiste): Cover, Fortschritt (spulen),
// Steuerung inkl. Zufall/Wiederholen, mehrere Player umschaltbar, App nach vorne holen
DropPanel {
    id: root
    panel: "media"
    center: true
    panelWidth: 420

    readonly property var players: Mpris.players.values
    property string chosen: ""              // uniqueId des gewählten Players (sonst der spielende)
    readonly property var player: players.find(p => p.uniqueId === chosen) ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    // position aktualisiert sich nicht selbst → regelmäßig neu lesen, solange sichtbar
    Timer {
        interval: 1000; repeat: true
        running: root.shown && (root.player?.isPlaying ?? false)
        onTriggered: root.player?.positionChanged()
    }
    onShownChanged: if (shown) player?.positionChanged()

    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0")
        return h ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`
    }

    // Player-Auswahl
    Flow {
        visible: root.players.length > 1
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: root.players
            delegate: Rectangle {
                required property var modelData
                readonly property bool sel: modelData === root.player
                implicitWidth: tabRow.implicitWidth + 20; implicitHeight: 28; radius: 9
                color: sel ? Theme.primary : (tabMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: 6
                    IconImage { implicitSize: 14; anchors.verticalCenter: parent.verticalCenter; source: Quickshell.iconPath(DesktopEntries.heuristicLookup(modelData.desktopEntry || modelData.identity)?.icon ?? "", "audio-x-generic") }
                    Text { text: modelData.identity + (modelData.isPlaying ? "  󰐊" : ""); color: sel ? Theme.fgOnPrimary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12 }
                }
                MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chosen = modelData.uniqueId }
            }
        }
    }

    Text {
        visible: !root.player
        Layout.fillWidth: true; Layout.topMargin: 16; Layout.bottomMargin: 16
        horizontalAlignment: Text.AlignHCenter
        text: "Nichts wird abgespielt"
        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
    }

    // Cover + Titel
    RowLayout {
        visible: root.player !== null
        Layout.fillWidth: true
        spacing: 14
        ClippingRectangle {
            Layout.preferredWidth: 110; Layout.preferredHeight: 110
            radius: 14
            color: Theme.surfaceContainerHighest
            Image { id: art; anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
            Text { anchors.centerIn: parent; visible: art.status !== Image.Ready; text: "󰝚"; color: Theme.fgMuted; font.pixelSize: 40; font.family: Theme.fontUi }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text { Layout.fillWidth: true; text: root.player?.trackTitle || "Unbekannter Titel"; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx + 3; font.bold: true; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; visible: text !== ""; text: root.player?.trackArtist ?? ""; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; visible: text !== ""; text: root.player?.trackAlbum ?? ""; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight }
            Item { Layout.fillHeight: true }
            Text {
                visible: root.player?.canRaise ?? false
                text: "󰏌  " + (root.player?.identity ?? "") + " öffnen"
                color: raiseMouse.containsMouse ? Theme.primary : Theme.fgMuted
                font.family: Theme.fontUi; font.pixelSize: 11
                MouseArea { id: raiseMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.player.raise(); Panels.close() } }
            }
        }
    }

    // Fortschritt
    ColumnLayout {
        visible: root.player !== null && (root.player?.lengthSupported ?? false) && (root.player?.length ?? 0) > 0
        Layout.fillWidth: true
        spacing: 2
        ThemeSlider {
            id: seek
            Layout.fillWidth: true
            opacity: root.player?.canSeek ? 1 : 0.6
            value: (root.player?.position ?? 0) / Math.max(1, root.player?.length ?? 1)
            onMoved: v => { if (root.player?.canSeek) root.player.position = v * root.player.length }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: root.fmt(root.player?.position ?? 0); color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }
            Text { text: root.fmt(root.player?.length ?? 0); color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }
        }
    }

    // Steuerung
    RowLayout {
        visible: root.player !== null
        Layout.alignment: Qt.AlignHCenter
        spacing: 10
        CtrlButton {
            visible: root.player?.shuffleSupported ?? false
            icon: "󰒟"; on: root.player?.shuffle ?? false
            onClicked: root.player.shuffle = !root.player.shuffle
        }
        CtrlButton { icon: "󰒮"; enabled: root.player?.canGoPrevious ?? false; onClicked: root.player.previous() }
        CtrlButton { icon: root.player?.isPlaying ? "󰏤" : "󰐊"; big: true; enabled: root.player?.canTogglePlaying ?? false; onClicked: root.player.togglePlaying() }
        CtrlButton { icon: "󰒭"; enabled: root.player?.canGoNext ?? false; onClicked: root.player.next() }
        CtrlButton {
            visible: root.player?.loopSupported ?? false
            readonly property int ls: root.player?.loopState ?? MprisLoopState.None
            icon: ls === MprisLoopState.Track ? "󰑘" : "󰑖"
            on: ls !== MprisLoopState.None
            onClicked: root.player.loopState = ls === MprisLoopState.None ? MprisLoopState.Playlist : ls === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
        }
    }

    component CtrlButton: Rectangle {
        id: cb
        property string icon
        property bool big: false
        property bool on: false
        property bool enabled: true
        signal clicked()
        implicitWidth: big ? 52 : 40; implicitHeight: implicitWidth
        radius: implicitWidth / 2
        opacity: enabled ? 1 : 0.4
        color: big ? (cbMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
             : on ? Qt.alpha(Theme.primary, 0.2)
             : (cbMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
        Text { anchors.centerIn: parent; text: cb.icon; font.family: Theme.fontUi; font.pixelSize: cb.big ? 24 : 18; color: cb.big ? Theme.fgOnPrimary : cb.on ? Theme.primary : Theme.fg }
        MouseArea { id: cbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (cb.enabled) cb.clicked() }
    }
}

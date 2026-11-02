import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Zwischenablage-Verlauf (cliphist): Suchen, Enter = erster Treffer, Klick = kopieren,
// Rechtsklick = löschen, Bildvorschau, Verlauf leeren
DropPanel {
    id: root
    panel: "clipboard"
    alignLeft: false
    panelWidth: 560
    grabKeys: true
    anchors { left: false; right: false }   // mittig

    readonly property string cache: Quickshell.env("HOME") + "/.cache/quickshell/clip"
    readonly property var imgRe: /^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) (\d+x\d+) \]\]$/
    property var items: []         // { line, text, image }
    property string query: ""
    readonly property var shown_: items.filter(i => !query.trim() || i.text.toLowerCase().includes(query.trim().toLowerCase())).slice(0, 60)

    onShownChanged: if (shown) { query = ""; search.text = ""; listProc.running = true; search.forceActiveFocus() }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(Boolean).map(line => {
                    const t = line.split("\t").slice(1).join("\t")
                    const m = t.match(root.imgRe)
                    return { line, text: m ? "Bild " + m[2].replace("x", " × ") : t, image: m ? `${root.cache}/${line.split("\t")[0]}.${m[1]}` : "" }
                })
                // Vorschaubilder der obersten Bilder erzeugen (gecacht)
                const imgs = root.items.slice(0, 20).filter(i => i.image)
                if (imgs.length)
                    Quickshell.execDetached(["bash", "-c", `mkdir -p "$1"; shift; while [ $# -gt 0 ]; do [ -s "$2" ] || printf '%s' "$1" | cliphist decode > "$2"; shift 2; done`,
                                             "_", root.cache, ...imgs.flatMap(i => [i.line, i.image])])
            }
        }
    }
    function copy(it) {
        Panels.close()
        Quickshell.execDetached(["bash", "-c", `printf '%s' "$1" | cliphist decode | wl-copy`, "_", it.line])
    }
    function remove(it) {
        Quickshell.execDetached(["bash", "-c", `printf '%s' "$1" | cliphist delete`, "_", it.line])
        items = items.filter(i => i !== it)
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Zwischenablage"; color: Theme.primary; font.family: Theme.fontAccent; font.pixelSize: 15; Layout.fillWidth: true }
        Rectangle {
            implicitWidth: wipeTxt.implicitWidth + 20; implicitHeight: 26; radius: 10
            color: wipe.containsMouse ? Theme.error : "transparent"
            Text { id: wipeTxt; anchors.centerIn: parent; text: "Verlauf leeren"; color: wipe.containsMouse ? Theme.fgOnError : Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12 }
            MouseArea { id: wipe; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["cliphist", "wipe"]); root.items = [] } }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 38
        radius: 12
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: search.activeFocus ? Theme.primary : Theme.outlineVariant
        TextInput {
            id: search
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            selectionColor: Theme.primary
            font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
            onTextChanged: root.query = text
            onAccepted: if (root.shown_.length) root.copy(root.shown_[0])
            Keys.onEscapePressed: Panels.close()
            Keys.onDownPressed: list.forceActiveFocus()
            Text { visible: !search.text; text: "Suchen … (Enter = erster Treffer)"; color: Theme.fgMuted; font: search.font; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: 440
        clip: true
        spacing: 4
        model: ScriptModel { values: root.shown_ }
        keyNavigationEnabled: true
        highlightMoveDuration: 0
        Keys.onReturnPressed: if (currentIndex >= 0) root.copy(root.shown_[currentIndex])
        Keys.onEscapePressed: Panels.close()
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: list.width
            implicitHeight: modelData.image ? 66 : 36
            radius: 10
            color: (clipMouse.containsMouse || (list.activeFocus && ListView.isCurrentItem)) ? Theme.surfaceContainerHigh : "transparent"
            Rectangle { visible: list.activeFocus && row.ListView.isCurrentItem; width: 3; height: parent.height - 12; radius: 2; color: Theme.primary; anchors { left: parent.left; verticalCenter: parent.verticalCenter } }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 10
                Rectangle {
                    visible: row.modelData.image !== ""
                    Layout.preferredWidth: 96; Layout.preferredHeight: 54
                    radius: 6; clip: true
                    color: Theme.surfaceContainerHighest
                    Image { anchors.fill: parent; source: row.modelData.image ? "file://" + row.modelData.image : ""; fillMode: Image.PreserveAspectCrop; cache: false; asynchronous: true }
                }
                Text {
                    text: row.modelData.text.replace(/\s+/g, " ").slice(0, 200)
                    color: Theme.fg
                    font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            MouseArea {
                id: clipMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => e.button === Qt.RightButton ? root.remove(row.modelData) : root.copy(row.modelData)
            }
        }
        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: root.items.length === 0 ? "Noch nichts kopiert" : "Keine Treffer"
            color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
        }
    }
}

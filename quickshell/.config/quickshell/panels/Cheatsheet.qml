import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Tastenkürzel-Übersicht (SUPER+/): liest keybinds.lua (scripts/keybinds.py), durchsuchbar
PanelWindow {
    id: win
    property bool open: false
    property var binds: []
    property string query: ""

    visible: open
    onOpenChanged: if (open) { proc.running = true; search.text = ""; search.forceActiveFocus() }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-cheatsheet"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: 1100
    implicitHeight: 720

    IpcHandler { target: "cheatsheet"; function toggle(): void { win.open = !win.open } }
    Process {
        id: proc
        command: ["python3", Quickshell.shellDir + "/scripts/keybinds.py"]
        stdout: StdioCollector { onStreamFinished: { try { win.binds = JSON.parse(text) } catch (e) {} } }
    }

    readonly property var shown: binds.filter(b => !query || (b.desc + " " + b.keys.join(" ") + " " + b.section).toLowerCase().includes(query.toLowerCase()))
    readonly property var sections: [...new Set(shown.map(b => b.section))]

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Qt.alpha(Theme.surfaceContainer, 0.97)
        border.width: 1
        border.color: Theme.outlineVariant

        ColumnLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Tastenkürzel"; color: Theme.fg; font.family: Theme.fontAccent; font.pixelSize: 22 }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: 300; implicitHeight: 36; radius: 10
                    color: Theme.surfaceContainerHigh
                    border.width: 1; border.color: search.activeFocus ? Theme.primary : Theme.outlineVariant
                    TextInput {
                        id: search
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                        onTextChanged: win.query = text
                        Keys.onEscapePressed: win.open = false
                        Text { visible: !search.text; anchors.verticalCenter: parent.verticalCenter; text: "Suchen …"; color: Theme.fgMuted; font: search.font }
                    }
                }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: flow.implicitHeight
                Flow {
                    id: flow
                    width: parent.width
                    spacing: 18
                    Repeater {
                        model: win.sections
                        delegate: ColumnLayout {
                            id: sec
                            required property string modelData
                            width: (flow.width - 36) / 3
                            spacing: 5
                            Text { text: sec.modelData; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: true; font.capitalization: Font.AllUppercase }
                            Repeater {
                                model: win.shown.filter(b => b.section === sec.modelData)
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Repeater {
                                        model: modelData.keys
                                        delegate: Rectangle {
                                            required property string modelData
                                            implicitWidth: kt.implicitWidth + 12; implicitHeight: 22; radius: 6
                                            color: Theme.surfaceContainerHighest
                                            border.width: 1; border.color: Theme.outlineVariant
                                            Text { id: kt; anchors.centerIn: parent; text: modelData; color: Theme.fg; font.family: Theme.fontMono; font.pixelSize: 11 }
                                        }
                                    }
                                    Text { Layout.fillWidth: true; Layout.leftMargin: 6; text: modelData.desc; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

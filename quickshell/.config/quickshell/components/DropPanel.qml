import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Gemeinsamer Rahmen für Panels unter der Leiste: blendet ein und gleitet leicht herab,
// Esc schließt, beim Schließen kurz sichtbar für die Animation.
PanelWindow {
    id: win
    required property string panel           // Name in Panels.open
    property string ns: "qs-" + panel        // Layer-Namespace (Unschärfe-Regel)
    property bool alignLeft: false           // sonst rechts
    property int panelWidth: 380
    property bool grabKeys: false            // Tastatur sofort (z. B. Suchfeld)
    default property alias content: inner.data
    readonly property bool shown: Panels.open === panel

    visible: shown || closing.running
    onShownChanged: if (!shown) closing.restart()
    Timer { id: closing; interval: Theme.anim + 60 }

    anchors { top: true; left: alignLeft; right: !alignLeft }
    margins { top: 6; left: 10; right: 10 }
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: ns
    WlrLayershell.keyboardFocus: !shown ? WlrKeyboardFocus.None : grabKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    color: "transparent"
    implicitWidth: panelWidth
    implicitHeight: frame.implicitHeight + 6

    Rectangle {
        id: frame
        width: parent.width
        implicitHeight: inner.implicitHeight + 28
        radius: 16
        color: Qt.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Theme.outlineVariant
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        transform: Translate {
            y: win.shown ? 0 : -14
            Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        }
        focus: win.shown
        Keys.onEscapePressed: Panels.close()

        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 12
        }
    }
}

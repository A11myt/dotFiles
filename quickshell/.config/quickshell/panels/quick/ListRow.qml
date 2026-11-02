import QtQuick
import QtQuick.Layouts
import qs

// Zeile in einer Unterseite: Symbol, Titel, Untertitel, rechts Zusatztext;
// aufklappbarer Bereich (default property) für Aktionen/Eingaben
Rectangle {
    id: r
    property string icon
    property string title
    property string sub: ""
    property color subColor: Theme.fgMuted
    property string trailing: ""
    property bool active: false             // verbunden/ausgewählt → Akzent
    property bool expanded: false
    property bool busy: false
    default property alias extra: more.data
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 16
    radius: 12
    color: active ? Qt.alpha(Theme.primary, 0.18) : (m.containsMouse || expanded ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.clicked() }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 12; rightMargin: 12 }
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: r.icon; color: r.active ? Theme.primary : Theme.fgMuted
                font.family: Theme.fontUi; font.pixelSize: 18
                Layout.preferredWidth: 22
                RotationAnimation on rotation { running: r.busy; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                onTextChanged: if (!r.busy) rotation = 0
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { text: r.title; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; font.bold: r.active; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { visible: text !== ""; text: r.sub; color: r.subColor; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Text { visible: text !== ""; text: r.trailing; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 13 }
        }
        ColumnLayout {
            id: more
            visible: r.expanded
            Layout.fillWidth: true
            spacing: 8
        }
    }
}

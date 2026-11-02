import QtQuick
import qs
import qs.services
import QtQuick.Effects

// Abgerundete „Pille“ wie in der AGS-Leiste: leichter Hintergrund, Schatten, Hover.
// Der Schatten hängt nur am Hintergrund – liegt er auf dem Ganzen, wird der Text
// als Textur gerendert und sieht verwaschen aus.
Item {
    id: pill
    property bool hovered: mouse.containsMouse
    property alias mouse: mouse
    default property alias content: row.data
    property int padX: 14
    property color hoverColor: Qt.alpha(Theme.surfaceVariant, 0.12)
    property color color: hovered ? hoverColor : Qt.alpha(Theme.surfaceVariant, 0.05)
    // Sichtbarkeit: eigene Bedingung des Elements (want) UND Einstellung der Leiste (barKey)
    property bool want: true
    property string barKey: ""
    visible: want && (barKey === "" || Config.barOn(barKey))
    signal clicked(var event)
    signal scrolled(var event)

    implicitWidth: row.implicitWidth + padX * 2
    implicitHeight: 28

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.pillRadius
        color: pill.color
        Behavior on color { ColorAnimation { duration: 200 } }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowOpacity: 0.25; shadowColor: "black" }
    }

    // hinter dem Inhalt: eigene Klickflächen im Inhalt (z. B. Arbeitsflächen) gehen vor
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => pill.clicked(e)
        onWheel: e => pill.scrolled(e)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}

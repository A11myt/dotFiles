import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Pill {
    id: p
    onClicked: Panels.toggle("calendar")
    SystemClock { id: clock; precision: SystemClock.Minutes }
    BarText { text: Qt.formatDateTime(clock.date, "hh:mm AP"); accent: p.hovered }
}

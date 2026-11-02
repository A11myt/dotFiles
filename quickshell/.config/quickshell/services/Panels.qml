pragma Singleton
import QtQuick
import Quickshell

// Aufklapp-Panels der Leiste: immer nur eins gleichzeitig offen
Singleton {
    property string open: "none"   // none | center | quick | calendar | clipboard
    function toggle(p) { open = (open === p) ? "none" : p }
    function close() { open = "none" }
}

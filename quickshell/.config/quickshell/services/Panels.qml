pragma Singleton
import QtQuick
import Quickshell

// Aufklapp-Panels der Leiste: immer nur eins gleichzeitig offen.
// page = Unterseite der Quick Settings (main | wifi | bluetooth | audio)
Singleton {
    property string open: "none"   // none | center | quick | calendar | clipboard
    property string page: "main"
    function toggle(p) { open = (open === p) ? "none" : p; page = "main" }
    function close() { open = "none" }
    // Quick Settings direkt auf einer Unterseite öffnen; nochmal = schließen
    function showPage(pg) {
        if (open === "quick" && page === pg) { open = "none"; return }
        page = pg
        open = "quick"
    }
}

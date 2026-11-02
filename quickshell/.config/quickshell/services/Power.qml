pragma Singleton
import QtQuick
import Quickshell

// Power-Menü offen/zu (CTRL+ALT+ENTF, Knopf in Quick Settings)
Singleton {
    property bool open: false
    function toggle() { open = !open }
}

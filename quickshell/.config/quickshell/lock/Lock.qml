import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Sperrbildschirm (loginctl lock-session → hypridle → `qs ipc call lock lock`, Rückfall hyprlock).
// Entsperren nur über PAM (Passwort) – es gibt bewusst keinen IPC-Weg zum Entsperren.
// `qs ipc call lock preview` zeigt die Oberfläche ohne zu sperren (Esc/Enter schließt, keine Prüfung).
Scope {
    id: root
    property bool locked: false
    property bool preview: false
    property string buffer: ""          // eingegebenes Passwort (nur im Speicher)
    property bool busy: false
    property bool failed: false
    property string message: ""

    IpcHandler {
        target: "lock"
        function lock(): void { root.buffer = ""; root.failed = false; root.message = ""; root.locked = true }
        function preview(): void { root.buffer = ""; root.preview = !root.preview }
    }

    PamContext {
        id: pam
        // eine Rückfrage (Passwort) → gepufferte Eingabe senden
        onPamMessage: {
            if (responseRequired) respond(root.buffer)
            else if (messageIsError) root.message = message
        }
        onCompleted: result => {
            root.busy = false
            if (result === PamResult.Success) {
                root.locked = false
                root.message = ""
            } else {
                root.failed = true
                root.message = result === PamResult.MaxTries ? "Zu viele Versuche – kurz warten" : "Falsches Passwort"
            }
            root.buffer = ""
        }
        onError: err => { root.busy = false; root.buffer = ""; root.failed = true; root.message = "Anmeldefehler: " + PamError.toString(err) }
    }

    function submit() {
        if (preview) { preview = false; return }
        if (buffer === "" || busy) return
        busy = true
        failed = false
        message = ""
        pam.start()
    }
    function type(e) {
        if (busy) return
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) submit()
        else if (e.key === Qt.Key_Escape) { if (preview) preview = false; buffer = "" }
        else if (e.key === Qt.Key_Backspace) buffer = (e.modifiers & Qt.ControlModifier) ? "" : buffer.slice(0, -1)
        else if (e.text && e.text.charCodeAt(0) >= 32) { buffer += e.text; failed = false }
    }

    WlSessionLock {
        locked: root.locked
        WlSessionLockSurface {
            color: "black"
            LockContent { anchors.fill: parent; lock: root }
        }
    }

    // Vorschau: normale Overlay-Ebene, kein Sperren
    PanelWindow {
        visible: root.preview
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-lock-preview"
        WlrLayershell.keyboardFocus: root.preview ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "black"
        LockContent { anchors.fill: parent; lock: root }
    }
}

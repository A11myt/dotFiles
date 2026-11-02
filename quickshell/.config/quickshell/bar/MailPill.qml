import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Ungelesene Mails (nur sichtbar, wenn es welche gibt); Klick öffnet das Webmail des ersten Postfachs mit neuen Mails
Pill {
    id: p
    want: Accounts.mail.unread > 0
    onClicked: {
        const a = (Accounts.mail.accounts ?? []).find(x => x.unread > 0 && x.web)
        if (a) Qt.openUrlExternally(a.web)
        else Quickshell.execDetached(["qs", "ipc", "call", "sidebar", "toggle"])
    }
    BarText { text: "󰇮 " + Accounts.mail.unread; accent: p.hovered }
    Tooltip {
        target: p; show: p.hovered
        text: (Accounts.mail.accounts ?? []).filter(a => a.unread).map(a => `${a.name}: ${a.unread} ungelesen` + (a.mails[0] ? `\n  ${a.mails[0].from}: ${a.mails[0].subject}` : "")).join("\n")
    }
}

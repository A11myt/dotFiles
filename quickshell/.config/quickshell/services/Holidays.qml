pragma Singleton
import QtQuick
import Quickshell

// Gesetzliche Feiertage in Deutschland, nach Bundesland (Config.holidayState, Standard HE).
// Bewegliche Feiertage über das Osterdatum (Gauß/Anonymer Gregorianischer Algorithmus).
Singleton {
    id: root
    readonly property string state: Config.holidayState
    readonly property var states: ({
        BW: "Baden-Württemberg", BY: "Bayern", BE: "Berlin", BB: "Brandenburg", HB: "Bremen", HH: "Hamburg",
        HE: "Hessen", MV: "Mecklenburg-Vorpommern", NI: "Niedersachsen", NW: "Nordrhein-Westfalen",
        RP: "Rheinland-Pfalz", SL: "Saarland", SN: "Sachsen", ST: "Sachsen-Anhalt", SH: "Schleswig-Holstein", TH: "Thüringen"
    })
    // Zwischenspeicher pro Jahr; wird nur innen verändert (kein Neuzuweisen) → keine Bindungsschleife
    readonly property var cache: ({})

    function easter(y) {
        const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4
        const f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30
        const i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451)
        const month = Math.floor((h + l - 7 * m + 114) / 31), day = ((h + l - 7 * m + 114) % 31) + 1
        return new Date(y, month - 1, day)
    }
    function key(d) { return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0") }
    function plus(d, n) { const x = new Date(d); x.setDate(x.getDate() + n); return x }

    // { "YYYY-MM-DD": "Name" } für ein Jahr
    function year(y) {
        const ck = y + state
        if (cache[ck]) return cache[ck]
        const s = state, o = easter(y), m = {}
        const add = (d, name, only) => { if (!only || only.indexOf(s) >= 0) m[key(d)] = name }
        add(new Date(y, 0, 1), "Neujahr")
        add(new Date(y, 0, 6), "Heilige Drei Könige", ["BW", "BY", "ST"])
        add(new Date(y, 2, 8), "Frauentag", ["BE", "MV"])
        add(plus(o, -2), "Karfreitag")
        add(o, "Ostersonntag", ["BB"])
        add(plus(o, 1), "Ostermontag")
        add(new Date(y, 4, 1), "Tag der Arbeit")
        add(plus(o, 39), "Christi Himmelfahrt")
        add(plus(o, 49), "Pfingstsonntag", ["BB"])
        add(plus(o, 50), "Pfingstmontag")
        add(plus(o, 60), "Fronleichnam", ["BW", "BY", "HE", "NW", "RP", "SL"])
        add(new Date(y, 7, 15), "Mariä Himmelfahrt", ["SL"])
        add(new Date(y, 8, 20), "Weltkindertag", ["TH"])
        add(new Date(y, 9, 3), "Tag der Deutschen Einheit")
        add(new Date(y, 9, 31), "Reformationstag", ["BB", "HB", "HH", "MV", "NI", "SN", "ST", "SH", "TH"])
        add(new Date(y, 10, 1), "Allerheiligen", ["BW", "BY", "NW", "RP", "SL"])
        // Buß- und Bettag: Mittwoch vor dem 23. November
        const nov23 = new Date(y, 10, 23)
        add(plus(nov23, -((nov23.getDay() + 4) % 7 || 7)), "Buß- und Bettag", ["SN"])
        add(new Date(y, 11, 25), "1. Weihnachtstag")
        add(new Date(y, 11, 26), "2. Weihnachtstag")
        cache[ck] = m
        return m
    }
    function name(d) { return year(d.getFullYear())[key(d)] ?? "" }
    // kein Feiertag, aber oft frei: als Hinweis zeigen
    function special(d) {
        const md = (d.getMonth() + 1) * 100 + d.getDate()
        return md === 1224 ? "Heiligabend" : md === 1231 ? "Silvester" : ""
    }
}

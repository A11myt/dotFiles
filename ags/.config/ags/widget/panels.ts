// Aufklapp-Panels der Leiste: immer nur eins gleichzeitig offen
import { createState } from "gnim"

export type Panel = "none" | "center" | "quick" | "calendar"

export const [openPanel, setOpenPanel] = createState<Panel>("none")

export const togglePanel = (p: Panel) => setOpenPanel(cur => (cur === p ? "none" : p))
export const closePanels = () => setOpenPanel("none")
export const isOpen = (p: Panel) => openPanel(cur => cur === p)

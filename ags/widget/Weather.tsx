import { createMemo, createState } from "gnim"
import { interval } from "ags/time"
import { execAsync } from "ags/process"
import GLib from "gi://GLib"

type WeatherData = { text: string; tooltip: string }

const SCRIPT = `${GLib.get_home_dir()}/.config/waybar/scripts/weather-openmeteo.sh`

export default function Weather() {
    const [data, setData] = createState<WeatherData>({ text: "?", tooltip: "loading..." })

    const fetch = () =>
        execAsync(["bash", SCRIPT])
            .then(out => setData(JSON.parse(out) as WeatherData))
            .catch(() => {})

    fetch()
    interval(600_000, fetch)

    const text = createMemo(() => data().text)
    const tip  = createMemo(() => data().tooltip)

    return (
        <button class="Weather" tooltipText={tip}>
            <label label={text} />
        </button>
    )
}

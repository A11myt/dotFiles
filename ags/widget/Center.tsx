import Notification from "./Notification"
import Media from "./Media"

export default function Center() {
    return (
        <box class="Center" spacing={8}>
            <Notification />
            <Media />
        </box>
    )
}

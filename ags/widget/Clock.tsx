import { createPoll } from "ags/time"

export default function Clock() {
    const time = createPoll("", 1000, "date '+%I:%M %p'")
    return (
        <button class="Clock">
            <label label={time} />
        </button>
    )
}

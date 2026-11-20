pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

/**
 * Night light through hyprsunset.
 *
 * The filter is on exactly when a hyprsunset daemon is running: starting it applies the
 * temperature, killing it restores the screen. Temperature changes while on go through
 * `hyprctl hyprsunset temperature`. (hyprsunset's own identity mode is not used because
 * it cannot be queried afterwards, so the shell could not tell whether the filter is on.)
 *
 * With the schedule on, toggling by hand overrides it until the next scheduled change.
 * With the schedule off, the running daemon is the state, so it survives shell restarts.
 */
Singleton {
    id: root

    readonly property int minTemperature: 2000
    readonly property int maxTemperature: 6500

    readonly property bool automatic: GlobalConfig.services.nightLight.automatic
    readonly property int temperature: clampTemperature(GlobalConfig.services.nightLight.colorTemperature)
    readonly property int fromMinutes: parseTime(GlobalConfig.services.nightLight.from, 20 * 60)
    readonly property int toMinutes: parseTime(GlobalConfig.services.nightLight.to, 8 * 60)
    readonly property bool hasSchedule: fromMinutes !== toMinutes
    readonly property bool scheduleActive: automatic && hasSchedule

    // Real state, from the last probe
    property bool available: true
    property bool active

    // Schedule state, recomputed every minute
    property bool scheduled
    property date nextChange

    // Desired state when the schedule is off
    property bool manual

    readonly property bool overridden: scheduleActive && persist.overrideUntil > 0
    readonly property bool wanted: {
        if (!scheduleActive)
            return manual;
        if (overridden)
            return persist.override;
        return scheduled;
    }

    property bool ready
    property bool applyPending

    // ---- Public API ----

    function setEnabled(on: bool): void {
        if (!scheduleActive) {
            manual = on;
        } else if (on === scheduled) {
            clearOverride();
        } else {
            persist.override = on;
            persist.overrideUntil = nextChange.getTime();
        }
    }

    function toggle(): void {
        setEnabled(!wanted);
    }

    function resumeSchedule(): void {
        clearOverride();
    }

    function setAutomatic(on: bool): void {
        GlobalConfig.services.nightLight.automatic = on;
    }

    function setTemperature(kelvin: int): void {
        GlobalConfig.services.nightLight.colorTemperature = clampTemperature(Math.round(kelvin / 100) * 100);
    }

    function refresh(): void {
        probeProc.running = true;
    }

    function formatClock(date: date): string {
        return Tr.formatDateTime(date, Units.twelveHourClock ? "h:mm a" : "hh:mm");
    }

    function formatMinutes(minutes: int): string {
        const d = new Date();
        d.setHours(Math.floor(minutes / 60), minutes % 60, 0, 0);
        return formatClock(d);
    }

    // One line describing what the filter is doing and what happens next
    readonly property string statusText: {
        if (!available)
            return Tr.tr("hyprsunset is not installed");
        if (!scheduleActive)
            return wanted ? Tr.tr("On") : Tr.tr("Off");

        const next = formatClock(nextChange);
        if (overridden)
            // TRANSLATORS: %1 = a clock time, e.g. 20:00
            return wanted ? Tr.tr("On until schedule resumes at %1").arg(next) : Tr.tr("Off until schedule resumes at %1").arg(next);
        // TRANSLATORS: %1 = a clock time, e.g. 20:00
        return wanted ? Tr.tr("On until %1").arg(next) : Tr.tr("Turns on at %1").arg(next);
    }

    readonly property string scheduleText: Tr.tr("%1 – %2").arg(formatMinutes(fromMinutes)).arg(formatMinutes(toMinutes))

    // ---- Schedule ----

    function clampTemperature(kelvin: int): int {
        return Math.max(minTemperature, Math.min(maxTemperature, kelvin));
    }

    function parseTime(str: string, fallback: int): int {
        const m = /^(\d{1,2}):(\d{2})$/.exec((str ?? "").trim());
        if (!m)
            return fallback;
        const h = Number(m[1]);
        const min = Number(m[2]);
        return h < 24 && min < 60 ? h * 60 + min : fallback;
    }

    function inWindow(t: int): bool {
        if (!hasSchedule)
            return false;
        if (fromMinutes < toMinutes)
            return t >= fromMinutes && t < toMinutes;
        return t >= fromMinutes || t < toMinutes; // Wraps past midnight
    }

    function clearOverride(): void {
        persist.override = false;
        persist.overrideUntil = 0;
    }

    function tick(): void {
        // Read the clock directly; bindings on Time.hours/minutes can lag a minute behind
        // when evaluated from a change handler
        const now = new Date();
        const t = now.getHours() * 60 + now.getMinutes();

        scheduled = inWindow(t);

        const target = scheduled ? toMinutes : fromMinutes;
        const delta = ((target - t) % 1440 + 1440) % 1440 || 1440;
        const next = new Date(now);
        next.setSeconds(0, 0);
        next.setMinutes(next.getMinutes() + delta);
        nextChange = next;

        if (persist.overrideUntil > 0 && now.getTime() >= persist.overrideUntil)
            clearOverride();
    }

    onFromMinutesChanged: {
        clearOverride();
        tick();
    }
    onToMinutesChanged: {
        clearOverride();
        tick();
    }
    onScheduleActiveChanged: {
        clearOverride();
        if (!scheduleActive)
            manual = active; // Keep whatever is on screen
        tick();
    }

    // ---- Applying ----

    onWantedChanged: {
        if (ready)
            applyDebounce.restart();
    }
    onTemperatureChanged: {
        if (ready && wanted)
            applyDebounce.restart();
    }

    function apply(): void {
        if (applyProc.running) {
            applyPending = true;
            return;
        }

        const t = temperature;
        applyProc.command = wanted ? ["sh", "-c", `if pidof -q hyprsunset; then hyprctl hyprsunset temperature ${t} >/dev/null; else setsid -f hyprsunset -t ${t} >/dev/null 2>&1; fi`] : ["sh", "-c", "pkill -x hyprsunset; true"];
        applyProc.running = true;
    }

    Component.onCompleted: {
        tick();
        refresh();
    }

    Connections {
        function onMinutesChanged(): void {
            root.tick();
        }

        target: Time
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        function enable(): void {
            root.setEnabled(true);
        }

        function disable(): void {
            root.setEnabled(false);
        }

        function resume(): void {
            root.resumeSchedule();
        }

        function setTemperature(kelvin: int): void {
            root.setTemperature(kelvin);
        }

        function status(): string {
            return JSON.stringify({
                on: root.wanted,
                running: root.active,
                temperature: root.temperature,
                automatic: root.automatic,
                scheduled: root.scheduled,
                overridden: root.overridden,
                nextChange: root.scheduleActive ? root.nextChange.toISOString() : null,
                text: root.statusText
            });
        }

        target: "nightlight"
    }

    // Coalesces slider drags and bursts of state changes into one command
    Timer {
        id: applyDebounce

        interval: 60
        onTriggered: root.apply()
    }

    // Survives hot reloads, so a manual override is not dropped on every config edit
    PersistentProperties {
        id: persist

        property bool override
        property real overrideUntil

        reloadableId: "nightLight"
    }

    Process {
        id: applyProc

        onExited: {
            if (root.applyPending) {
                root.applyPending = false;
                root.apply();
            } else {
                root.refresh();
            }
        }
    }

    Process {
        id: probeProc

        command: ["sh", "-c", "command -v hyprsunset >/dev/null || echo missing; pidof -q hyprsunset && echo running; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = !text.includes("missing");
                root.active = text.includes("running");

                if (!root.ready) {
                    root.manual = root.active;
                    root.ready = true;
                    // Bring the schedule and the configured temperature in line with the screen
                    if (root.active || root.wanted)
                        root.apply();
                } else if (!applyProc.running && !root.applyPending && !applyDebounce.running && root.active !== root.wanted) {
                    // Started or killed outside the shell: follow it by hand, enforce it on a schedule
                    if (root.scheduleActive)
                        root.apply();
                    else
                        root.manual = root.active;
                }
            }
        }
    }
}
// reload-test

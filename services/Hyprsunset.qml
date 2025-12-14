pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

/**
 * Simple hyprsunset service with automatic mode.
 * Controls blue light filter to reduce eye strain during night hours.
 */
Singleton {
    id: root

    property string from: Config.services.nightLight.from
    property string to: Config.services.nightLight.to
    property bool automatic: Config.services.nightLight.automatic
    property int colorTemperature: Config.services.nightLight.colorTemperature
    property bool shouldBeOn: false
    property bool firstEvaluation: true
    property bool active: false
    readonly property int minutesPerDay: 24 * 60

    property var parsedFrom: parseTime(from, 19, 0)
    property var parsedTo: parseTime(to, 6, 30)
    property int fromMinutes: parsedFrom.hour * 60 + parsedFrom.minute
    property int toMinutes: parsedTo.hour * 60 + parsedTo.minute

    property int clockHour: Time.hours
    property int clockMinute: Time.minutes
    property int nowMinutes: (clockHour * 60 + clockMinute) % minutesPerDay

    property var manualActive
    property int manualActiveHour: 0
    property int manualActiveMinute: 0

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        root.manualActive = undefined;
        root.firstEvaluation = true;
        reEvaluate();
    }
    onFromChanged: {
        root.manualActive = undefined;
        reEvaluate(true);
    }
    onToChanged: {
        root.manualActive = undefined;
        reEvaluate(true);
    }

    Component.onCompleted: reEvaluate(true);

    function parseTime(timeString, fallbackHour, fallbackMinute) {
        if (typeof timeString !== "string")
            return {hour: fallbackHour, minute: fallbackMinute};

        const parts = timeString.split(":");
        const hour = Number(parts[0]);
        const minute = Number(parts[1]);

        const validHour = Number.isFinite(hour) && hour >= 0 && hour < 24 ? hour : fallbackHour;
        const validMinute = Number.isFinite(minute) && minute >= 0 && minute < 60 ? minute : fallbackMinute;
        return {hour: validHour, minute: validMinute};
    }

    function inBetween(t, from, to) {
        if (from < to)
            return (t >= from && t <= to);

        // Wrapped around midnight
        return (t >= from || t <= to);
    }

    function minutesUntil(target, from) {
        let delta = target - from;
        if (delta < 0)
            delta += minutesPerDay;
        return delta;
    }

    function reEvaluate(forceEnsure = false) {
        const t = nowMinutes;
        const from = fromMinutes;
        const to = toMinutes;
        let clearedManualOverride = false;

        if (root.manualActive !== undefined) {
            const manualActiveTime = (manualActiveHour * 60 + manualActiveMinute) % minutesPerDay;
            const manualTarget = inBetween(manualActiveTime, from, to) ? to : from;
            const timeSinceManual = minutesUntil(t, manualActiveTime);
            const timeUntilBoundary = minutesUntil(manualTarget, manualActiveTime);

            if (timeSinceManual >= timeUntilBoundary) {
                clearedManualOverride = true;
                root.manualActive = undefined;
            }
        }

        const newShouldBeOn = inBetween(t, from, to);
        if (newShouldBeOn !== root.shouldBeOn) {
            root.shouldBeOn = newShouldBeOn;
        } else if (forceEnsure || clearedManualOverride) {
            root.ensureState();
        }

        if (firstEvaluation) {
            firstEvaluation = false;
            root.ensureState();
        }
    }

    onShouldBeOnChanged: ensureState()

    function ensureState() {
        if (!root.automatic || root.manualActive !== undefined)
            return;
        if (root.shouldBeOn) {
            root.enable();
        } else {
            root.disable();
        }
    }

    function enable() {
        root.active = true;
        console.log("[Hyprsunset] Enabling with temperature:", root.colorTemperature);
        Quickshell.execDetached(["bash", "-c", `pidof hyprsunset || hyprsunset --temperature ${root.colorTemperature}`]);
    }

    function disable() {
        root.active = false;
        console.log("[Hyprsunset] Disabling");
        Quickshell.execDetached(["bash", "-c", `pkill hyprsunset`]);
    }

    function fetchState() {
        fetchProc.running = true;
    }

    Process {
        id: fetchProc

        running: true
        command: ["bash", "-c", "hyprctl hyprsunset temperature"]
        stdout: StdioCollector {
            id: stateCollector

            onStreamFinished: {
                const output = stateCollector.text.trim();
                if (output.length == 0 || output.startsWith("Couldn't"))
                    root.active = false;
                else
                    root.active = (output != "6500");
            }
        }
    }

    function toggle(active = undefined) {
        console.log("[Hyprsunset] Toggle called with active:", active, "current manualActive:", root.manualActive, "current active:", root.active);

        root.manualActive = active !== undefined ? active : !root.active;
        root.manualActiveHour = root.clockHour;
        root.manualActiveMinute = root.clockMinute;
        console.log("[Hyprsunset] Setting manualActive to:", root.manualActive);

        if (root.manualActive) {
            root.enable();
        } else {
            root.disable();
        }
    }

    // Change temperature when config changes
    Connections {
        target: Config.services.nightLight

        function onColorTemperatureChanged() {
            if (!root.active)
                return;
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", `${Config.services.nightLight.colorTemperature}`]);
        }
    }
}

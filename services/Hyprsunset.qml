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
    property bool shouldBeOn
    property bool firstEvaluation: true
    property bool active: false

    property int fromHour: Number(from.split(":")[0])
    property int fromMinute: Number(from.split(":")[1])
    property int toHour: Number(to.split(":")[0])
    property int toMinute: Number(to.split(":")[1])

    property int clockHour: Time.hours
    property int clockMinute: Time.minutes

    property var manualActive
    property int manualActiveHour
    property int manualActiveMinute

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        root.manualActive = undefined;
        root.firstEvaluation = true;
        reEvaluate();
    }

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t <= to);
        } else {
            // Wrapped around midnight
            return (t >= from || t <= to);
        }
    }

    function reEvaluate() {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;
        const manualActive = manualActiveHour * 60 + manualActiveMinute;

        if (root.manualActive !== undefined && (inBetween(from, manualActive, t) || inBetween(to, manualActive, t))) {
            root.manualActive = undefined;
        }
        root.shouldBeOn = inBetween(t, from, to);
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
        
        if (root.manualActive === undefined) {
            root.manualActive = root.active;
            root.manualActiveHour = root.clockHour;
            root.manualActiveMinute = root.clockMinute;
        }

        root.manualActive = active !== undefined ? active : !root.manualActive;
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

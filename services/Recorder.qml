pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    property bool needsStart
    property list<string> startArgs: []
    property bool needsStop
    property bool needsPause

    function start(extraArgs = []): void {
        needsStart = true;
        startArgs = extraArgs || [];
        checkProc.running = true;
    }

    function stop(): void {
        needsStop = true;
        checkProc.running = true;
    }

    function togglePause(): void {
        needsPause = true;
        checkProc.running = true;
    }

    QtObject {
        id: props
        property bool running: false
        property bool paused: false
        property real elapsed: 0
    }

    Process {
        id: checkProc

        running: true
        command: ["pidof", "gpu-screen-recorder"]
        onExited: code => {
            const isActuallyRunning = (code === 0);
            
            if (isActuallyRunning) {
                if (root.needsStop) {
                    Quickshell.execDetached(["caelestia", "record"]);
                    props.running = false;
                    props.paused = false;
                    props.elapsed = 0;
                } else if (root.needsPause) {
                    Quickshell.execDetached(["caelestia", "record", "-p"]);
                    props.paused = !props.paused;
                } else {
                    props.running = true;
                }
            } else {
                if (root.needsStart) {
                    Quickshell.execDetached(["caelestia", "record", ...root.startArgs]);
                    props.running = true;
                    props.paused = false;
                    props.elapsed = 0;
                } else {
                    props.running = false;
                    props.paused = false;
                    props.elapsed = 0;
                }
            }

            root.needsStart = false;
            root.needsStop = false;
            root.needsPause = false;
        }
    }

    Timer {
        interval: props.running ? 1000 : 3000
        repeat: true
        running: true
        onTriggered: checkProc.running = true
    }

    Connections {
        function onSecondsChanged(): void {
            props.elapsed++;
        }

        target: Time
        enabled: props.running && !props.paused
    }
}

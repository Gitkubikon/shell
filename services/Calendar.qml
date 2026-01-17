pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/**
 * Calendar service backed by the Caelestia CLI (`caelestia calendar --json`),
 * which already aggregates Google/CalDAV sources. Exposes a list of events and
 * helpers to look up events for a specific date.
 */
Singleton {
    id: root

    // Kept for compatibility with the dashboard UI; true when the CLI backend
    // is available and responding.
    property bool khalAvailable: false
    property bool loading: false
    property string errorMessage: ""
    property var events: []
    property var eventsMap: ({})

    readonly property int refreshIntervalMs: Config.services?.calendarUpdateInterval ?? 300000

    Component.onCompleted: {
        // Start initial backend check
        backendCheckProcess.running = true;
    }

    /**
     * Return events that occur on the same day as `date`.
     */
    function eventsOn(date) {
        if (!khalAvailable || !date)
            return [];

        const d = new Date(date);
        const key = d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
        return eventsMap[key] || [];
    }

    /**
     * Trigger a refresh from the CLI backend.
     */
    function refresh() {
        if (!khalAvailable)
            return;

        errorMessage = "";
        loading = true;

        console.log("[Calendar] Refreshing events from CLI backend...");

        const startDate = new Date();
        startDate.setMonth(startDate.getMonth() - 24); // fetch wide range so browsing past/future months still shows dots
        const endDate = new Date();
        endDate.setMonth(endDate.getMonth() + 24);

        const startStr = Qt.formatDate(startDate, "yyyy-MM-dd");
        const dayCount = Math.max(1, Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24)) + 1);

        getEventsProcess.command = [
            "/bin/bash", "-c",
            "export PATH=$HOME/.local/bin:$PATH; exec caelestia calendar -s " + startStr + " -d " + dayCount.toString() + " --json"
        ];
        getEventsProcess.running = true;
    }

    function sameDay(a, b) {
        return a.getDate() === b.getDate()
            && a.getMonth() === b.getMonth()
            && a.getFullYear() === b.getFullYear();
    }

    function colorFromTitle(title) {
        let hash = 0;
        for (let i = 0; i < title.length; ++i)
            hash = ((hash << 5) - hash) + title.charCodeAt(i);

        const hue = ((hash % 360) + 360) % 360;
        return Qt.hsla(hue / 360, 0.6, 0.6, 1.0);
    }

    Process {
        id: backendCheckProcess

        command: ["/bin/bash", "-c", "export PATH=$HOME/.local/bin:$PATH; exec caelestia calendar -d 1 --json"]
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector { id: backendCheckStderr }
        onExited: (exitCode) => {
            root.khalAvailable = (exitCode === 0);
            if (root.khalAvailable) {
                console.log("[Calendar] CLI backend check succeeded");
                root.errorMessage = "";
                root.refresh();
                refreshTimer.start();
                backendRetryTimer.stop();
            } else {
                root.errorMessage = qsTr("caelestia calendar command failed (exit %1)").arg(exitCode);
                console.warn("[Calendar] Caelestia calendar backend not available; retrying in 5 seconds...");
                if (backendCheckStderr.text.trim().length > 0)
                    console.warn("[Calendar] Backend stderr:", backendCheckStderr.text.trim());
                backendRetryTimer.start();
            }
        }
    }

    Timer {
        id: backendRetryTimer
        interval: 5000  // Retry every 5 seconds
        repeat: true
        onTriggered: {
            if (!root.khalAvailable) {
                console.log("[Calendar] Retrying backend check...");
                backendCheckProcess.running = true;
            } else {
                stop();
            }
        }
    }

    Process {
        id: getEventsProcess

        running: false
        stdout: StdioCollector {
            id: eventsCollector
        }

        onExited: exitCode => {
            root.loading = false;

            if (exitCode !== 0) {
                root.khalAvailable = false;
                root.errorMessage = qsTr("caelestia calendar command failed (exit %1)").arg(exitCode);
                root.events = [];
                console.warn("[Calendar] CLI backend returned non-zero exit", exitCode);
                return;
            }

            try {
                const rawText = eventsCollector.text?.trim() ?? "";
                console.log("[Calendar] Raw CLI output length:", rawText.length);
                const parsed = rawText.length > 0 ? JSON.parse(rawText) : [];

                let skipped = 0;
                root.events = parsed.map(evt => {
                    const startMs = Date.parse(evt.start);
                    const endMs = Date.parse(evt.end);
                    if (!evt.start || !evt.end || isNaN(startMs) || isNaN(endMs)) {
                        skipped++;
                        console.warn("[Calendar] Skipping invalid event", JSON.stringify(evt).slice(0, 200));
                        return null;
                    }

                    const startDate = new Date(startMs);
                    const endDate = new Date(endMs);

                    return {
                        content: evt.title ?? evt.summary ?? "",
                        title: evt.title ?? evt.summary ?? "",
                        startDate,
                        endDate,
                        startIso: evt.start,
                        endIso: evt.end,
                        color: colorFromTitle(evt.title ?? evt.summary ?? "")
                    };
                }).filter(e => e !== null);

                if (root.events.length > 0) {
                    const sample = root.events[0];
                    console.log("[Calendar] Parsed events count:", root.events.length, "skipped invalid:", skipped, "sample:", sample.startIso, sample.content);
                } else {
                    console.log("[Calendar] Parsed events count: 0", "skipped invalid:", skipped);
                }

                // Build lookup map
                const newMap = {};
                for (const evt of root.events) {
                    const d = evt.startDate;
                    const key = d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
                    if (!newMap[key]) newMap[key] = [];
                    newMap[key].push(evt);
                }
                root.eventsMap = newMap;

                root.errorMessage = "";
                root.khalAvailable = true;
            } catch (e) {
                console.error("[Calendar] Failed to parse calendar output:", e);
                root.errorMessage = qsTr("Failed to parse calendar output");
                root.events = [];
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshIntervalMs
        repeat: true
        onTriggered: root.refresh()
    }
}

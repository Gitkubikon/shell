pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Caelestia
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

MouseArea {
    id: root

    required property LazyLoader loader
    required property ShellScreen screen

    // OCR state
    property var ocrRegions: []
    property int hoveredIndex: -1
    property bool ocrComplete: false
    property string ocrError: ""

    // Selection state
    property int selectionStart: -1
    property int selectionEnd: -1
    property bool isSelecting: false

    // Screenshot path for OCR
    property string screenshotPath: ""

    anchors.fill: parent
    opacity: 0
    hoverEnabled: true
    cursorShape: ocrRegions.length > 0 ? Qt.PointingHandCursor : Qt.WaitCursor

    Component.onCompleted: {
        opacity = 1;
    }

    function startOcr(): void {
        // Save screenshot to temp file for OCR daemon
        const timestamp = Date.now();
        screenshotPath = `/tmp/caelestia-ocr-${Quickshell.processId}-${timestamp}.png`;

        // Save the screencopy content to file
        CUtils.saveItem(screencopy, Qt.resolvedUrl(screenshotPath), Qt.rect(0, 0, screen.width, screen.height), path => {
            console.log("[clicktodo] Screenshot saved to:", path);
            // Connect to OCR daemon and send request
            sendOcrRequest();
            ocrProcess.connectToServer();
        });
    }

    function sendOcrRequest(): void {
        const request = JSON.stringify({
            cmd: loader.liveMode ? "stream_ocr" : "ocr_full",
            path: screenshotPath,
            fast: loader.fastMode
        }) + "\n";

        console.log("[clicktodo] Sending OCR request:", request.trim());
        ocrProcess.sendRequest(request);
    }

    function parseOcrResponse(data: string): void {
        const lines = data.split("\n").filter(l => l.trim());

        for (const line of lines) {
            try {
                const msg = JSON.parse(line);

                if (msg.type === "det") {
                    // Detection results - boxes found
                    console.log("[clicktodo] Detection found", msg.boxes?.length || 0, "regions");
                } else if (msg.type === "update") {
                    // Single region recognized - add box immediately
                    addRegion(msg);
                } else if (msg.type === "done") {
                    ocrComplete = true;
                    console.log("[clicktodo] OCR complete:", msg.emitted, "regions");
                } else if (msg.type === "error") {
                    ocrError = msg.message || "Unknown error";
                    console.log("[clicktodo] OCR error:", ocrError);
                } else if (msg.status === "success" && msg.boxes) {
                    // Full OCR response (non-streaming)
                    for (let i = 0; i < msg.boxes.length; i++) {
                        addRegion({
                            box: msg.boxes[i],
                            bbox: computeBbox(msg.boxes[i]),
                            text: msg.texts[i],
                            conf: msg.scores[i]
                        });
                    }
                    ocrComplete = true;
                } else if (msg.status === "error") {
                    ocrError = msg.error || "Unknown error";
                }
            } catch (e) {
                console.log("[clicktodo] Parse error:", e, "for line:", line);
            }
        }
    }

    function computeBbox(box: var): var {
        if (!box || box.length < 4) return [0, 0, 0, 0];
        const xs = box.map(p => p[0]);
        const ys = box.map(p => p[1]);
        return [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
    }

    function addRegion(msg: var): void {
        const box = msg.box || [];
        const bbox = msg.bbox || computeBbox(box);
        const text = msg.text || "";
        const conf = msg.conf || 0;

        if (!text.trim()) return;

        // Scale coordinates from image space to screen space
        const scale = screencopy.scale || 1.0;
        const scaledBbox = [
            bbox[0] / scale,
            bbox[1] / scale,
            bbox[2] / scale,
            bbox[3] / scale
        ];

        const region = {
            polygon: box.map(p => [p[0] / scale, p[1] / scale]),
            bbox: scaledBbox,
            text: text,
            confidence: conf
        };

        ocrRegions = [...ocrRegions, region];
    }

    function copyText(text: string): void {
        Quickshell.execDetached(["wl-copy", text]);
        Quickshell.execDetached(["notify-send", "-a", "caelestia-cli", "OCR Click-to-Copy",
            `Copied: ${text.substring(0, 50)}${text.length > 50 ? "..." : ""}`]);
        closeOverlay();
    }

    function closeOverlay(): void {
        closeAnim.start();
    }

    function cleanup(): void {
        // Remove temp screenshot
        if (screenshotPath) {
            Quickshell.execDetached(["rm", "-f", screenshotPath]);
        }
    }

    // Mouse interaction
    onPositionChanged: event => {
        // Find hovered region
        hoveredIndex = -1;
        for (let i = 0; i < ocrRegions.length; i++) {
            const r = ocrRegions[i];
            const [x0, y0, x1, y1] = r.bbox;
            if (event.x >= x0 && event.x <= x1 && event.y >= y0 && event.y <= y1) {
                hoveredIndex = i;
                break;
            }
        }
    }

    onClicked: event => {
        if (hoveredIndex >= 0 && hoveredIndex < ocrRegions.length) {
            copyText(ocrRegions[hoveredIndex].text);
        }
    }

    focus: true
    Keys.onEscapePressed: closeOverlay()

    // Close animation
    SequentialAnimation {
        id: closeAnim

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        Anim {
            target: root
            property: "opacity"
            to: 0
            duration: Appearance.anim.durations.large
        }
        ScriptAction {
            script: root.cleanup()
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    // Screen capture - instant freeze
    ScreencopyView {
        id: screencopy
        anchors.fill: parent
        captureSource: root.screen

        onHasContentChanged: {
            if (hasContent) {
                root.startOcr();
            }
        }
    }

    // Subtle overlay tint
    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3surface
        opacity: 0.15
    }

    // OCR regions
    Repeater {
        model: root.ocrRegions

        Rectangle {
            id: regionRect

            required property var modelData
            required property int index

            property bool isHovered: root.hoveredIndex === index
            property var bbox: modelData.bbox || [0, 0, 0, 0]

            x: bbox[0]
            y: bbox[1]
            width: Math.max(1, bbox[2] - bbox[0])
            height: Math.max(1, bbox[3] - bbox[1])

            color: isHovered ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.25)
                            : Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.08)
            border.color: isHovered ? Colours.palette.m3primary : Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.4)
            border.width: isHovered ? 2 : 1
            radius: 4

            Behavior on color { CAnim {} }
            Behavior on border.color { CAnim {} }
            Behavior on border.width { Anim { duration: 100 } }

            // Glow effect on hover
            layer.enabled: isHovered
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.3
                blurMax: 16
            }
        }
    }

    // Loading indicator
    Rectangle {
        visible: !root.ocrComplete && root.ocrRegions.length === 0
        anchors.centerIn: parent
        width: 200
        height: 60
        radius: 12
        color: Colours.palette.m3surfaceContainer
        opacity: 0.95

        Text {
            anchors.centerIn: parent
            text: root.ocrError || "Detecting text..."
            color: root.ocrError ? Colours.palette.m3error : Colours.palette.m3onSurface
            font.pixelSize: 14
        }
    }

    // No text found message
    Rectangle {
        visible: root.ocrComplete && root.ocrRegions.length === 0 && !root.ocrError
        anchors.centerIn: parent
        width: 200
        height: 60
        radius: 12
        color: Colours.palette.m3surfaceContainer
        opacity: 0.95

        Text {
            anchors.centerIn: parent
            text: "No text detected"
            color: Colours.palette.m3onSurface
            font.pixelSize: 14
        }
    }

    // Help text at bottom
    Rectangle {
        visible: root.ocrRegions.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        width: helpText.width + 32
        height: 36
        radius: 18
        color: Colours.palette.m3surfaceContainer
        opacity: 0.9

        Text {
            id: helpText
            anchors.centerIn: parent
            text: "Click text to copy • ESC to cancel"
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: 12
        }
    }

    // Fade in
    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.large
        }
    }

    // OCR daemon connection via ncat
    Process {
        id: ocrProcess

        property bool connected: false
        property string pendingRequest: ""

        command: ["stdbuf", "-oL", "ncat", "-U", "/tmp/caelestia_ocrd.sock"]
        stdinEnabled: true

        onRunningChanged: {
            if (running) {
                connected = true;
                console.log("[clicktodo] Connected to OCR daemon");
                if (pendingRequest) {
                    write(pendingRequest);
                    pendingRequest = "";
                }
            } else {
                connected = false;
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.log("[clicktodo] OCR process exited with code:", exitCode);
            if (exitCode !== 0 && !root.ocrComplete) {
                root.ocrError = "OCR daemon connection failed";
            }
        }

        stdout: SplitParser {
            onRead: data => {
                console.log("[clicktodo] Got OCR response");
                root.parseOcrResponse(data);
            }
        }

        stderr: SplitParser {
            onRead: data => {
                console.log("[clicktodo] OCR stderr:", data);
            }
        }

        function connectToServer(): void {
            running = true;
        }

        function sendRequest(request: string): void {
            if (connected) {
                write(request);
            } else {
                pendingRequest = request;
            }
        }
    }
}

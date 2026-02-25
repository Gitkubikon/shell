pragma ComponentBehavior: Bound

import qs.components.containers
import qs.components.misc
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    LazyLoader {
        id: root

        property bool fastMode: false
        property bool liveMode: false
        property bool closing: false

        Variants {
            model: Quickshell.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "clicktodo"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
                mask: root.closing ? empty : null

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Region {
                    id: empty
                }

                Overlay {
                    loader: root
                    screen: win.modelData
                }
            }
        }
    }

    IpcHandler {
        target: "clicktodo"

        function open(): void {
            console.log("[clicktodo] IPC open() called");
            root.fastMode = false;
            root.liveMode = true;  // Default to streaming for progressive results
            root.closing = false;
            root.activeAsync = true;
        }

        function openFast(): void {
            root.fastMode = true;
            root.liveMode = true;  // Default to streaming
            root.closing = false;
            root.activeAsync = true;
        }

        function openBatch(): void {
            root.fastMode = false;
            root.liveMode = false;  // Non-streaming, wait for all results
            root.closing = false;
            root.activeAsync = true;
        }

        function openFastBatch(): void {
            root.fastMode = true;
            root.liveMode = false;
            root.closing = false;
            root.activeAsync = true;
        }
    }

    CustomShortcut {
        name: "clicktodo"
        description: "Open OCR click-to-copy"
        onPressed: {
            root.fastMode = false;
            root.liveMode = true;
            root.closing = false;
            root.activeAsync = true;
        }
    }

    CustomShortcut {
        name: "clicktodoFast"
        description: "Open OCR click-to-copy (fast mode)"
        onPressed: {
            root.fastMode = true;
            root.liveMode = true;
            root.closing = false;
            root.activeAsync = true;
        }
    }
}

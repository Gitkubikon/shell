pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.components
import qs.services

Singleton {
    property ShellRoot shellRoot

    // Local: hot corner (top left) toggles the overview. State lives here rather
    // than in Interactions.qml because that is instantiated per screen, which
    // registered the "hotcorner" IPC target once per monitor (only the first
    // registration was used, so `hotcorner ignore` suppressed one screen only).
    property bool hotCornerCooldown

    function suppressHotCorner(): void {
        hotCornerCooldown = true;
        hotCornerTimer.restart();
    }

    // Local: run cmd once the panels have animated away. Panel cards live in a
    // Loader that unloads the moment the panel hides (the hide anim overshoots,
    // so that is ~200ms in), which kills any Timer owned by the card before it
    // fires. Screen grabbing tools (area picker, region record) need the panels
    // gone first, so the delay has to live somewhere that outlives the card.
    property list<string> pendingExec: []

    function execAfterHide(cmd: list<string>): void {
        pendingExec = cmd;
        execAfterHideTimer.restart();
    }

    function anySidebarOpen(): bool {
        return states.instances.some(s => s.sidebar);
    }

    function forScreen(screen: ShellScreen): ScreenState {
        for (const s of states.instances)
            if (s.modelData === screen)
                return s;
        return null;
    }

    function forActive(): ScreenState {
        const mon = Hypr.focusedMonitor;
        for (const s of states.instances)
            if (Hypr.monitorFor(s.modelData) === mon)
                return s;
        return null;
    }

    function componentsFor(screen: ShellScreen): Components {
        for (const c of components.instances)
            if (c.modelData === screen)
                return c;
        return null;
    }

    function componentsForActive(): Components {
        const mon = Hypr.focusedMonitor;
        for (const c of components.instances)
            if (Hypr.monitorFor(c.modelData) === mon)
                return c;
        return null;
    }

    Variants {
        id: states

        model: Screens.screens

        ScreenState {}
    }

    Variants {
        id: components

        model: Screens.screens

        Components {}
    }

    component Components: QtObject {
        required property ShellScreen modelData

        property var background
        property var rootWindow
        property var interactionWrapper
        property var bar
        property var panels

        function find(name: string, rootItem: Item): var {
            return CUtils.findChild(rootItem ?? rootWindow?.contentItem, name);
        }

        function findAll(name: string, rootItem: Item): var {
            return CUtils.findChildren(rootItem ?? rootWindow?.contentItem, name);
        }

        function findMatching(pattern: string, rootItem: Item): var {
            return CUtils.findChildrenMatching(rootItem ?? rootWindow?.contentItem, pattern);
        }
    }

    component ComponentRef: QtObject {
        required property ShellScreen screen
        required property string slot
        required property var component

        readonly property QtObject target: ShellState.componentsFor(screen)

        onTargetChanged: {
            if (target)
                target[slot] = component;
        }
        Component.onDestruction: {
            if (target && target[slot] === component)
                target[slot] = null;
        }
    }

    Timer {
        id: hotCornerTimer

        interval: 1000
        onTriggered: ShellState.hotCornerCooldown = false
    }

    Timer {
        id: execAfterHideTimer

        interval: 300
        onTriggered: {
            if (ShellState.pendingExec.length > 0) {
                Quickshell.execDetached(ShellState.pendingExec);
                ShellState.pendingExec = [];
            }
        }
    }

    IpcHandler {
        function ignore(): void {
            ShellState.suppressHotCorner();
        }

        target: "hotcorner"
    }

}

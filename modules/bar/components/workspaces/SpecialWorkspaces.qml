pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property string activeSpecial: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? monitor : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name ?? ""

    ListView {
        id: view

        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall
        interactive: false

        currentIndex: model.values.findIndex(w => w.name === root.activeSpecial)
        onCurrentIndexChanged: currentIndex = Qt.binding(() => model.values.findIndex(w => w.name === root.activeSpecial))

        // Local: sort special workspaces by their numeric suffix so the order is stable
        model: ScriptModel {
            values: Hypr.workspaces.values.filter(w => w.name.startsWith("special:") && (!GlobalConfig.bar.workspaces.perMonitorWorkspaces || w.monitor === root.monitor)).sort((a, b) => {
                const aNum = parseInt(a.name.slice(8));
                const bNum = parseInt(b.name.slice(8));
                if (isNaN(aNum) && isNaN(bNum))
                    return 0;
                if (isNaN(aNum))
                    return 1;
                if (isNaN(bNum))
                    return -1;
                return aNum - bNum;
            })
        }

        // Local: the pill highlight is animated by hand, so disable the built in one
        highlightFollowsCurrentItem: false
        highlightMoveDuration: 0

        highlight: Config.bar.workspaces.activeIndicator ? highlightComp : null

        delegate: SpecialWsDelegate {}

        Component {
            id: highlightComp

            StyledRect {
                // Bind to currentItem position manually for proper easing
                y: view.currentItem?.y ?? 0
                implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
                implicitHeight: view.currentItem?.implicitHeight ?? 0
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary
                visible: view.currentIndex >= 0

                // Scale in on first appearance
                scale: 0
                Component.onCompleted: scale = 1

                Behavior on y {
                    Anim {
                        type: Anim.Emphasized
                    }
                }

                Behavior on implicitHeight {
                    Anim {
                        type: Anim.Emphasized
                    }
                }

                Behavior on scale {
                    Anim {
                        easing: Tokens.anim.standardDecel
                    }
                }
            }
        }
    }

    MouseArea {
        property real startY

        anchors.fill: view

        drag.target: view.contentItem
        drag.axis: Drag.YAxis
        drag.maximumY: 0
        drag.minimumY: Math.min(0, view.height - view.contentHeight - Tokens.padding.extraSmall)

        onPressed: event => startY = event.y

        onClicked: event => {
            if (Math.abs(event.y - startY) > drag.threshold)
                return;

            const ws = view.itemAt(event.x, event.y) as SpecialWsDelegate;
            if (ws?.modelData)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${ws.modelData.name.slice(8)}")` : `togglespecialworkspace ${ws.modelData.name.slice(8)}`);
            else
                Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.workspace.toggle_special("special")' : "togglespecialworkspace special");
        }
    }

    component SpecialWsDelegate: ColumnLayout {
        id: ws

        required property HyprlandWorkspace modelData

        readonly property bool isActive: modelData.name === root.activeSpecial
        readonly property bool isOccupied: modelData.lastIpcObject.windows > 0
        readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindowsOnSpecialWorkspaces
        readonly property string icon: Icons.getSpecialWsIcon(modelData.name)
        readonly property color fgColour: isActive && Config.bar.workspaces.activeIndicator ? Colours.palette.m3onPrimary : Config.bar.workspaces.occupiedBg || isOccupied ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)

        anchors.left: view.contentItem.left
        anchors.right: view.contentItem.right

        spacing: 0

        Loader {
            id: label

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small

            sourceComponent: ws.icon.length === 1 ? letterComp : iconComp

            Component {
                id: iconComp

                MaterialIcon {
                    fill: 1
                    text: ws.icon
                    color: ws.fgColour
                    verticalAlignment: Qt.AlignVCenter
                }
            }

            Component {
                id: letterComp

                StyledText {
                    font: Tokens.font.body.builders.small.scale(0.85).build()
                    text: ws.icon
                    color: ws.fgColour
                    verticalAlignment: Qt.AlignVCenter
                    horizontalAlignment: Qt.AlignHCenter
                    elide: Text.ElideNone
                    wrapMode: Text.NoWrap
                }
            }
        }

        Loader {
            id: windows

            asynchronous: true

            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            Layout.topMargin: -Tokens.sizes.bar.innerWidth / 10

            visible: active
            active: ws.hasWindows

            // Local: show a dot per window instead of per app icons
            sourceComponent: Column {
                spacing: 0

                add: Transition {
                    Anim {
                        properties: "scale"
                        from: 0
                        to: 1
                        easing: Tokens.anim.standardDecel
                    }
                }

                move: Transition {
                    Anim {
                        properties: "scale"
                        to: 1
                        easing: Tokens.anim.standardDecel
                    }
                    Anim {
                        properties: "x,y"
                    }
                }

                Repeater {
                    model: ws.modelData?.lastIpcObject.windows ?? 0

                    StyledRect {
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                        opacity: 0.6
                    }
                }
            }
        }
    }
}

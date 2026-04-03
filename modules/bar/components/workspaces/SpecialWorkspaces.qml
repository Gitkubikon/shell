pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.components.effects
import qs.services
import qs.config
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property string activeSpecial: (Config.bar.workspaces.perMonitorWorkspaces ? monitor : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name ?? ""

    ListView {
        id: view

        anchors.fill: parent
        spacing: Math.floor(Appearance.spacing.small / 2)
        interactive: false

        currentIndex: model.values.findIndex(w => w.name === root.activeSpecial)
        onCurrentIndexChanged: currentIndex = Qt.binding(() => model.values.findIndex(w => w.name === root.activeSpecial))

        model: ScriptModel {
            values: Hypr.workspaces.values.filter(w => w.name.startsWith("special:") && (!Config.bar.workspaces.perMonitorWorkspaces || w.monitor === root.monitor)).sort((a, b) => {
                const aNum = parseInt(a.name.slice(8));
                const bNum = parseInt(b.name.slice(8));
                if (isNaN(aNum) && isNaN(bNum)) return 0;
                if (isNaN(aNum)) return 1;
                if (isNaN(bNum)) return -1;
                return aNum - bNum;
            })
        }

        // Disable ListView's built-in highlight animation — we handle it ourselves
        highlightFollowsCurrentItem: false
        highlightMoveDuration: 0

        highlight: Config.bar.workspaces.activeIndicator ? highlightComp : null

        Component {
            id: highlightComp

            StyledRect {
                // Bind to currentItem position manually for proper easing
                y: view.currentItem?.y ?? 0
                implicitWidth: Config.bar.sizes.innerWidth - Appearance.padding.small * 2
                implicitHeight: view.currentItem?.implicitHeight ?? 0
                radius: Appearance.rounding.full
                color: Colours.palette.m3primary
                visible: view.currentIndex >= 0

                Behavior on y {
                    Anim {
                        easing.bezierCurve: Appearance.anim.curves.emphasized
                    }
                }

                Behavior on implicitHeight {
                    Anim {
                        easing.bezierCurve: Appearance.anim.curves.emphasized
                    }
                }

                // Scale in on first appearance
                scale: 0
                Component.onCompleted: scale = 1
                Behavior on scale {
                    Anim {
                        easing.bezierCurve: Appearance.anim.curves.standardDecel
                    }
                }
            }
        }

        delegate: ColumnLayout {
            id: ws

            required property HyprlandWorkspace modelData
            required property int index
            readonly property bool isActive: modelData.name === root.activeSpecial
            readonly property bool isOccupied: modelData.lastIpcObject.windows > 0
            readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindowsOnSpecialWorkspaces
            readonly property string icon: Icons.getSpecialWsIcon(modelData.name)

            anchors.left: view.contentItem.left
            anchors.right: view.contentItem.right

            spacing: 0

            Loader {
                id: label

                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                Layout.preferredHeight: Config.bar.sizes.innerWidth - Appearance.padding.small * 2

                sourceComponent: ws.icon.length === 1 ? letterComp : iconComp

                Component {
                    id: iconComp

                    MaterialIcon {
                        fill: 1
                        text: ws.icon
                        color: ws.isActive && Config.bar.workspaces.activeIndicator
                            ? Colours.palette.m3onPrimary
                            : Config.bar.workspaces.occupiedBg || ws.isOccupied
                                ? Colours.palette.m3onSurface
                                : Colours.layer(Colours.palette.m3outlineVariant, 2)
                        verticalAlignment: Qt.AlignVCenter

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.durations.normal
                                easing.bezierCurve: Appearance.anim.curves.emphasized
                            }
                        }
                    }
                }

                Component {
                    id: letterComp

                    StyledText {
                        font.pointSize: Appearance.font.size.smaller * 0.85
                        text: ws.icon
                        color: ws.isActive && Config.bar.workspaces.activeIndicator
                            ? Colours.palette.m3onPrimary
                            : Config.bar.workspaces.occupiedBg || ws.isOccupied
                                ? Colours.palette.m3onSurface
                                : Colours.layer(Colours.palette.m3outlineVariant, 2)
                        verticalAlignment: Qt.AlignVCenter
                        horizontalAlignment: Qt.AlignHCenter
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.durations.normal
                                easing.bezierCurve: Appearance.anim.curves.emphasized
                            }
                        }
                    }
                }
            }

            Loader {
                id: windows

                asynchronous: true

                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.topMargin: -Config.bar.sizes.innerWidth / 10

                visible: active
                active: ws.hasWindows

                sourceComponent: Column {
                    spacing: 0

                    add: Transition {
                        Anim {
                            properties: "scale"
                            from: 0
                            to: 1
                            easing.bezierCurve: Appearance.anim.curves.standardDecel
                        }
                    }

                    move: Transition {
                        Anim {
                            properties: "scale"
                            to: 1
                            easing.bezierCurve: Appearance.anim.curves.standardDecel
                        }
                        Anim {
                            properties: "x,y"
                        }
                    }

                    Repeater {
                        model: ws.modelData.lastIpcObject.windows

                        delegate: StyledRect {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: Appearance.rounding.small / 2
                            color: Colours.palette.m3primary
                            opacity: 0.6
                        }
                    }
                }
            }
        }
    }
}

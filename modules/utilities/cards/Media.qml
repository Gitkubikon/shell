pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

/**
 * Combined screenshot + recording card. Replaces upstream's Record card: the
 * recordings tab is a superset of it (same start modes, same live controls) and
 * the screenshots tab adds a browser for the screenshot directory.
 */
StyledRect {
    id: root

    required property var props
    required property ScreenState screenState

    // 0 = screenshots, 1 = recordings
    property int tabIndex: props.utilitiesMediaTab

    readonly property real nonAnimHeight: btnLayout.implicitHeight + body.implicitHeight + layout.spacing + layout.anchors.margins * 2

    readonly property list<MenuItem> screenshotItems: [
        MenuItem {
            icon: "fullscreen"
            text: qsTr("Screenshot fullscreen")
            activeText: qsTr("Fullscreen")
            onClicked: root.exec(["caelestia", "screenshot"], false)
        },
        MenuItem {
            icon: "crop_free"
            text: qsTr("Screenshot area")
            activeText: qsTr("Area")
            onClicked: root.exec(["caelestia", "shell", "picker", "openFreeze"], true)
        },
        MenuItem {
            icon: "web_asset"
            text: qsTr("Screenshot window")
            activeText: qsTr("Window")
            onClicked: root.exec(["caelestia", "shell", "picker", "open"], true)
        }
    ]

    readonly property list<MenuItem> recordingItems: [
        MenuItem {
            icon: "fullscreen"
            text: qsTr("Record fullscreen")
            activeText: qsTr("Fullscreen")
            onClicked: Recorder.start()
        },
        MenuItem {
            icon: "screenshot_region"
            text: qsTr("Record region")
            activeText: qsTr("Region")
            // Goes through the area picker so the region is scale-correct
            onClicked: root.exec(["caelestia", "shell", "picker", "openRecord"], true)
        },
        MenuItem {
            icon: "select_to_speak"
            text: qsTr("Record fullscreen with sound")
            activeText: qsTr("Fullscreen")
            onClicked: Recorder.start(["-s"])
        },
        MenuItem {
            icon: "volume_up"
            text: qsTr("Record region with sound")
            activeText: qsTr("Region")
            onClicked: root.exec(["caelestia", "shell", "picker", "openRecordSound"], true)
        }
    ]

    /**
     * Hides the shell then runs cmd. Area based tools need the panels gone
     * before they grab the screen, so those get a short delay. The delay runs
     * from ShellState: this card is unloaded as soon as the panel hides, so a
     * Timer here would be destroyed before it fires.
     */
    function exec(cmd: list<string>, delayed: bool): void {
        root.screenState.utilities = false;
        root.screenState.sidebar = false;

        if (delayed)
            ShellState.execAfterHide(cmd);
        else
            Quickshell.execDetached(cmd);
    }

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            id: btnLayout

            spacing: Tokens.spacing.medium
            z: 1

            TabChip {
                index: 0
                icon: "screenshot_monitor"
                active: root.tabIndex === 0
            }

            TabChip {
                index: 1
                icon: "screen_record"
                active: root.tabIndex === 1
                recording: Recorder.running
            }

            Item {
                Layout.fillWidth: true
            }

            SplitButton {
                Layout.leftMargin: Tokens.spacing.medium

                disabled: root.tabIndex === 1 && Recorder.running
                menuItems: root.tabIndex === 0 ? root.screenshotItems : root.recordingItems
                active: root.tabIndex === 0 ? (root.screenshotItems.find(m => root.props.screenshotMode === m.icon + m.text) ?? root.screenshotItems[0]) : (root.recordingItems.find(m => root.props.recordingMode === m.icon + m.text) ?? root.recordingItems[0])
                menu.onItemSelected: item => {
                    if (root.tabIndex === 0)
                        root.props.screenshotMode = item.icon + item.text;
                    else
                        root.props.recordingMode = item.icon + item.text;
                }
            }
        }

        Loader {
            id: body

            // 0 = screenshot list, 1 = recording list, 2 = live recording controls
            property int mode: root.tabIndex === 1 ? (Recorder.running ? 2 : 1) : 0

            asynchronous: true
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            sourceComponent: mode === 2 ? recordingControls : mode === 1 ? recordingList : screenshotList
            clip: Layout.preferredHeight < implicitHeight

            Behavior on Layout.preferredHeight {
                id: bodyHeightAnim

                enabled: false

                Anim {}
            }

            Behavior on mode {
                SequentialAnimation {
                    Anim {
                        target: body
                        property: "opacity"
                        to: 0
                        type: Anim.DefaultEffects
                    }
                    PropertyAction {
                        target: bodyHeightAnim
                        property: "enabled"
                        value: true
                    }
                    PropertyAction {}
                    ParallelAnimation {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: 100
                            }
                            PropertyAction {
                                target: bodyHeightAnim
                                property: "enabled"
                                value: false
                            }
                        }
                        Anim {
                            target: body
                            property: "opacity"
                            to: 1
                            type: Anim.SlowEffects
                        }
                    }
                }
            }
        }
    }

    Component {
        id: screenshotList

        MediaList {
            props: root.props
            screenState: root.screenState

            title: qsTr("Screenshots")
            emptyText: qsTr("No screenshots found")
            itemText: qsTr("Screenshot at %1")
            emptyIcon: "image"

            path: Paths.shotsdir
            nameFilters: ["screenshot_*.png"]
            filePrefix: "screenshot"

            openIcon: "photo_library"
            openApp: GlobalConfig.general.apps.image
            confirmDeleteProp: "screenshotConfirmDelete"
        }
    }

    Component {
        id: recordingList

        MediaList {
            props: root.props
            screenState: root.screenState

            title: qsTr("Recordings")
            emptyText: qsTr("No recordings found")
            itemText: qsTr("Recording at %1")
            emptyIcon: "videocam"

            path: Paths.recsdir
            nameFilters: ["recording_*.mp4"]
            filePrefix: "recording"

            openIcon: "play_arrow"
            openApp: GlobalConfig.general.apps.playback
            confirmDeleteProp: "recordingConfirmDelete"
        }
    }

    Component {
        id: recordingControls

        RowLayout {
            spacing: Tokens.spacing.medium

            StyledRect {
                radius: Tokens.rounding.full
                color: Recorder.paused ? Colours.palette.m3tertiary : Colours.palette.m3error

                implicitWidth: recText.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: recText.implicitHeight + Tokens.padding.large

                StyledText {
                    id: recText

                    anchors.centerIn: parent
                    animate: true
                    text: Recorder.paused ? "PAUSED" : "REC"
                    color: Recorder.paused ? Colours.palette.m3onTertiary : Colours.palette.m3onError
                    font: Tokens.font.mono.small
                }

                Behavior on implicitWidth {
                    Anim {}
                }

                SequentialAnimation on opacity {
                    running: !Recorder.paused
                    alwaysRunToEnd: true
                    loops: Animation.Infinite

                    Anim {
                        from: 1
                        to: 0
                        duration: Tokens.anim.durations.large
                        easing: Tokens.anim.emphasizedAccel
                    }
                    Anim {
                        from: 0
                        to: 1
                        duration: Tokens.anim.durations.extraLarge
                        easing: Tokens.anim.emphasizedDecel
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    const elapsed = Recorder.elapsed;

                    const hours = Math.floor(elapsed / 3600);
                    const mins = Math.floor((elapsed % 3600) / 60);
                    const secs = Math.floor(elapsed % 60).toString().padStart(2, "0");

                    let time;
                    if (hours > 0)
                        time = `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
                    else
                        time = `${mins}:${secs}`;

                    return qsTr("Recording for %1").arg(time);
                }
                font: Tokens.font.body.medium
                elide: Text.ElideMiddle
            }

            ButtonRow {
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    shapeMorph: true
                    isRound: true
                    label.animate: true
                    icon: Recorder.paused ? "play_arrow" : "pause"
                    isToggle: true
                    checked: Recorder.paused
                    type: IconButton.Tonal
                    font: Tokens.font.icon.medium
                    onClicked: {
                        Recorder.togglePause();
                        internalChecked = Recorder.paused;
                    }

                    implicitWidth: {
                        // Ensure even size so icon is centered properly
                        const h = label.implicitHeight + Tokens.padding.large * 2;
                        return h % 2 === 0 ? h : h + 1;
                    }
                }

                IconButton {
                    shapeMorph: true
                    isRound: true
                    icon: "stop"
                    inactiveColour: Colours.palette.m3error
                    inactiveOnColour: Colours.palette.m3onError
                    font: Tokens.font.icon.medium
                    onClicked: Recorder.stop()

                    implicitWidth: {
                        // Ensure even size so icon is centered properly
                        const h = label.implicitHeight + Tokens.padding.large * 2;
                        return h % 2 === 0 ? h : h + 1;
                    }
                }
            }
        }
    }

    component TabChip: StyledRect {
        id: chip

        required property int index
        required property string icon
        required property bool active
        property bool recording

        implicitWidth: implicitHeight
        implicitHeight: {
            const h = chipIcon.implicitHeight + Tokens.padding.small * 2;
            return h - (h % 2);
        }

        radius: Tokens.rounding.full
        color: chip.active ? (chip.recording ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer) : Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)

        StateLayer {
            onClicked: {
                root.tabIndex = chip.index;
                root.props.utilitiesMediaTab = chip.index;
            }
        }

        MaterialIcon {
            id: chipIcon

            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1

            text: chip.icon
            color: chip.active ? (chip.recording ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer) : Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.large
        }

        Behavior on color {
            CAnim {}
        }
    }
}

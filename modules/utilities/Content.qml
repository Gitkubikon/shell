pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.utilities.cards
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property var props
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property matrix4x4 deformMatrix

    readonly property int enabledCards: (idleInhibit.active ? 1 : 0) + (nightLight.active ? 1 : 0) + (media.active ? 1 : 0) + (toggles.active ? 1 : 0)
    readonly property real nonAnimHeight: ((idleInhibit.item as IdleInhibit)?.nonAnimHeight ?? 0) + ((nightLight.item as NightLight)?.nonAnimHeight ?? 0) + ((media.item as Media)?.nonAnimHeight ?? 0) + ((toggles.item as Toggles)?.implicitHeight ?? 0) + layout.spacing * Math.max(0, enabledCards - 1)

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        Loader {
            id: idleInhibit

            Layout.fillWidth: true
            active: Config.utilities.cards.keepAwake
            visible: active

            sourceComponent: IdleInhibit {
                objectName: "utilitiesKeepAwake"
            }
        }

        Loader {
            id: nightLight

            Layout.fillWidth: true
            // No dedicated config key upstream; night light is a local feature and always shown
            active: true
            visible: active

            sourceComponent: NightLight {
                objectName: "utilitiesNightLight"
            }
        }

        Loader {
            id: media

            Layout.fillWidth: true
            active: Config.utilities.cards.recorder
            visible: active
            z: 1

            // Combined media card: screenshots + recordings in tabs (replaces upstream's Record card)
            sourceComponent: Media {
                objectName: "utilitiesMedia"

                props: root.props
                screenState: root.screenState
            }
        }

        Loader {
            id: toggles

            Layout.fillWidth: true
            active: Config.utilities.cards.quickToggles
            visible: active

            sourceComponent: Toggles {
                objectName: "utilitiesQuickToggles"

                screenState: root.screenState
                popouts: root.popouts
            }
        }
    }

    RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }

    ScreenshotDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }
}

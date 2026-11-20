import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    readonly property real nonAnimHeight: layout.implicitHeight + Tokens.padding.large * 2
    readonly property int tempRange: Hyprsunset.maxTemperature - Hyprsunset.minTemperature

    implicitHeight: nonAnimHeight

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    // The daemon can be started or killed outside the shell
    Component.onCompleted: Hyprsunset.refresh()

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Tokens.padding.large

                radius: Tokens.rounding.full
                color: Hyprsunset.wanted ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: Hyprsunset.wanted ? "bedtime" : "bedtime_off"
                    color: Hyprsunset.wanted ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Night light")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Hyprsunset.statusText
                    color: Hyprsunset.available ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3error
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                    animate: true
                }
            }

            StyledSwitch {
                enabled: Hyprsunset.available
                checked: Hyprsunset.wanted
                onToggled: Hyprsunset.setEnabled(checked)
            }
        }

        // Left is cool (high K), right is warm (low K)
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "light_mode"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.small
            }

            StyledSlider {
                Layout.fillWidth: true

                implicitHeight: Tokens.padding.medium * 2
                radius: Tokens.rounding.small
                enabled: Hyprsunset.available

                value: (Hyprsunset.maxTemperature - Hyprsunset.temperature) / root.tempRange
                onInteraction: v => Hyprsunset.setTemperature(Hyprsunset.maxTemperature - v * root.tempRange)
            }

            MaterialIcon {
                text: "bedtime"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.minimumWidth: tempMetrics.advanceWidth
                horizontalAlignment: Text.AlignRight
                text: Tr.tr("%1K").arg(Hyprsunset.temperature)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium

                TextMetrics {
                    id: tempMetrics

                    text: "0000K"
                    font: Tokens.font.label.medium
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconTextButton {
                type: IconTextButton.Tonal
                isToggle: true
                checked: Hyprsunset.automatic
                icon: "schedule"
                text: Hyprsunset.scheduleText
                disabled: !Hyprsunset.available
                onClicked: Hyprsunset.setAutomatic(!Hyprsunset.automatic)
            }

            Item {
                Layout.fillWidth: true
            }

            IconTextButton {
                visible: Hyprsunset.overridden
                type: IconTextButton.Text
                icon: "restart_alt"
                text: Tr.tr("Resume schedule")
                onClicked: Hyprsunset.resumeSchedule()
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}

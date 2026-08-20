import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    readonly property int tempMin: 1200
    readonly property int tempMax: 6500
    readonly property string scheduleText: formatSchedule(GlobalConfig.services.nightLight.from, GlobalConfig.services.nightLight.to)
    readonly property real nonAnimHeight: layout.implicitHeight + Tokens.padding.extraLargeIncreased

    function formatTimeString(timeString: string): string {
        const parts = (timeString ?? "").split(":");
        const hour = Number(parts[0]);
        const minute = Number(parts[1]);
        if (!Number.isFinite(hour) || !Number.isFinite(minute))
            return "";

        const d = new Date();
        d.setHours(hour, minute, 0, 0);
        return Qt.formatDateTime(d, GlobalConfig.services.useTwelveHourClock ? "hh:mm AP" : "hh:mm");
    }

    function formatSchedule(fromString: string, toString: string): string {
        const fromFormatted = formatTimeString(fromString);
        const toFormatted = formatTimeString(toString);
        if (fromFormatted.length && toFormatted.length)
            return `${fromFormatted} - ${toFormatted}`;
        return `${fromString} - ${toString}`;
    }

    function sliderToTemp(value: real): int {
        return Math.round(root.tempMax - value * (root.tempMax - root.tempMin));
    }

    function tempToSlider(temp: int): real {
        const clamped = Math.max(root.tempMin, Math.min(root.tempMax, temp));
        return (root.tempMax - clamped) / (root.tempMax - root.tempMin);
    }

    implicitHeight: nonAnimHeight

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    Component.onCompleted: Hyprsunset.fetchState()

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
                color: Hyprsunset.active ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: GlobalConfig.services.nightLight.automatic ? "schedule" : "bedtime"
                    color: Hyprsunset.active ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Night Light")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("%1 • %2K • %3").arg(Hyprsunset.active ? qsTr("Active now") : qsTr("Off")).arg(GlobalConfig.services.nightLight.colorTemperature).arg(root.scheduleText)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                    animate: true
                }
            }

            StyledSwitch {
                checked: Hyprsunset.active
                onToggled: Hyprsunset.toggle(checked)
            }
        }

        StyledSlider {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small

            implicitHeight: Tokens.padding.medium * 2
            radius: Tokens.rounding.small

            value: root.tempToSlider(GlobalConfig.services.nightLight.colorTemperature)
            onInteraction: v => {
                const temp = root.sliderToTemp(v);
                GlobalConfig.services.nightLight.colorTemperature = temp;
                if (temp >= root.tempMax) {
                    if (Hyprsunset.active)
                        Hyprsunset.toggle(false);
                } else if (!Hyprsunset.active) {
                    Hyprsunset.toggle(true);
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: -Tokens.spacing.small

            StyledText {
                text: qsTr("%1K").arg(root.tempMax)
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: qsTr("%1K").arg(root.tempMin)
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}

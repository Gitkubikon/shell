import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    readonly property int tempMin: 1200
    readonly property int tempMax: 6500
    readonly property string scheduleText: formatSchedule(Config.services.nightLight.from, Config.services.nightLight.to)

    function formatTimeString(timeString: string): string {
        if (typeof timeString !== "string")
            return "";

        const parts = timeString.split(":");
        const hour = Number(parts[0]);
        const minute = Number(parts[1]);
        if (!Number.isFinite(hour) || !Number.isFinite(minute))
            return "";

        const d = new Date();
        d.setHours(hour, minute, 0, 0);
        return Qt.formatDateTime(d, Config.services.useTwelveHourClock ? "hh:mm AP" : "hh:mm");
    }

    function formatSchedule(fromString: string, toString: string): string {
        const fromFormatted = formatTimeString(fromString);
        const toFormatted = formatTimeString(toString);
        if (fromFormatted.length && toFormatted.length)
            return `${fromFormatted} - ${toFormatted}`;
        return `${fromString} - ${toString}`;
    }

    function sliderToTemp(value: real): int {
        return Math.round(root.tempMax - (value * (root.tempMax - root.tempMin)));
    }

    function tempToSlider(temp: int): real {
        const clamped = Math.max(root.tempMin, Math.min(root.tempMax, temp));
        return (root.tempMax - clamped) / (root.tempMax - root.tempMin);
    }

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    radius: Appearance.rounding.normal
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Appearance.padding.smaller * 2

                radius: Appearance.rounding.full
                color: Hyprsunset.active ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: Config.services.nightLight.automatic ? "schedule" : "bedtime"
                    color: Hyprsunset.active ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
                    font.pointSize: Appearance.font.size.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Night Light")
                    font.pointSize: Appearance.font.size.normal
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("%1 - %2K - %3")
                        .arg(Hyprsunset.active ? qsTr("Active now") : qsTr("Off"))
                        .arg(Config.services.nightLight.colorTemperature)
                        .arg(root.scheduleText)
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }

        }

        StyledSlider {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small
            implicitHeight: Appearance.padding.normal * 3

            from: 0
            to: 1
            value: root.tempToSlider(Config.services.nightLight.colorTemperature)
            onMoved: {
                const temp = root.sliderToTemp(value);
                Config.services.nightLight.colorTemperature = temp;
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
            Layout.topMargin: -Appearance.spacing.small

            StyledText {
                text: `${root.tempMax}K`
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.smaller
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: `${root.tempMin}K`
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.smaller
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small
            visible: Config.services.nightLight.automatic && Hyprsunset.active
            text: qsTr("Active from %1 to %2").arg(Config.services.nightLight.from).arg(Config.services.nightLight.to)
            color: Colours.palette.m3outline
            font.pointSize: Appearance.font.size.smaller
            wrapMode: Text.WordWrap

            opacity: Config.services.nightLight.automatic && Hyprsunset.active ? 1 : 0

            Behavior on opacity {
                Anim {}
            }
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Component.onCompleted: {
        Hyprsunset.fetchState();
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property int tempMin: 1200
    readonly property int tempMax: 6500

    // The slider runs warm -> cool left to right, so 0 is the coolest (highest K)
    function sliderToTemp(value: real): int {
        return Math.round(root.tempMax - value * (root.tempMax - root.tempMin));
    }

    function tempToSlider(temp: int): real {
        const clamped = Math.max(root.tempMin, Math.min(root.tempMax, temp));
        return (root.tempMax - clamped) / (root.tempMax - root.tempMin);
    }

    function formatTime(timeString: string): string {
        const parts = (timeString ?? "").split(":");
        const hour = Number(parts[0]);
        const minute = Number(parts[1]);
        if (!Number.isFinite(hour) || !Number.isFinite(minute))
            return timeString;

        const d = new Date();
        d.setHours(hour, minute, 0, 0);
        return Qt.formatDateTime(d, GlobalConfig.services.useTwelveHourClock ? "hh:mm AP" : "hh:mm");
    }

    title: qsTr("Night light")

    Component.onCompleted: Hyprsunset.fetchState()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enable now")
            subtext: qsTr("Reduce blue light to ease eye strain")
            checked: Hyprsunset.active
            onToggled: Hyprsunset.toggle(checked)
        }

        ToggleRow {
            last: true
            text: qsTr("Automatic schedule")
            subtext: GlobalConfig.services.nightLight.automatic ? qsTr("Enabled between %1 and %2").arg(root.formatTime(GlobalConfig.services.nightLight.from)).arg(root.formatTime(GlobalConfig.services.nightLight.to)) : qsTr("Turn night light on and off at set times")
            checked: GlobalConfig.services.nightLight.automatic
            onToggled: GlobalConfig.services.nightLight.automatic = checked
        }

        // Colour temperature
        SectionHeader {
            text: qsTr("Colour temperature")
        }

        SliderRow {
            first: true
            last: true
            icon: "brightness_medium"
            label: qsTr("Warmth")
            valueLabel: qsTr("%1K").arg(GlobalConfig.services.nightLight.colorTemperature)
            value: root.tempToSlider(GlobalConfig.services.nightLight.colorTemperature)
            onMoved: v => {
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

        // Schedule
        SectionHeader {
            text: qsTr("Schedule")
        }

        TextFieldRow {
            first: true
            label: qsTr("From")
            subtext: qsTr("Time night light turns on")
            errorText: qsTr("Must be a 24 hour time, e.g. 20:00")
            value: GlobalConfig.services.nightLight.from
            placeholderText: "20:00"
            maximumLength: 5
            smallField: true
            validate: /^([01]\d|2[0-3]):[0-5]\d$/
            onEditingFinished: value => {
                if (field.valid)
                    GlobalConfig.services.nightLight.from = value;
            }
        }

        TextFieldRow {
            last: true
            label: qsTr("To")
            subtext: qsTr("Time night light turns off")
            errorText: qsTr("Must be a 24 hour time, e.g. 08:00")
            value: GlobalConfig.services.nightLight.to
            placeholderText: "08:00"
            maximumLength: 5
            smallField: true
            validate: /^([01]\d|2[0-3]):[0-5]\d$/
            onEditingFinished: value => {
                if (field.valid)
                    GlobalConfig.services.nightLight.to = value;
            }
        }

        // About
        SectionHeader {
            text: qsTr("About")
        }

        InfoRow {
            first: true
            last: true
            icon: "info"
            label: qsTr("Powered by hyprsunset")
            subtext: qsTr("Lower temperatures are warmer (more red), higher are cooler (more blue)")
            value: Hyprsunset.active ? qsTr("Active") : qsTr("Off")
        }
    }
}

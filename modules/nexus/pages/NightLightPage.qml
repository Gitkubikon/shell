pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property int tempRange: Hyprsunset.maxTemperature - Hyprsunset.minTemperature
    readonly property var timePattern: /^([01]\d|2[0-3]):[0-5]\d$/

    title: Tr.tr("Night light")

    // The daemon can be started or killed outside the shell
    Component.onCompleted: Hyprsunset.refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            last: !resumeRow.visible
            enabled: Hyprsunset.available
            text: Tr.tr("Night light")
            subtext: Hyprsunset.statusText
            checked: Hyprsunset.wanted
            onToggled: Hyprsunset.setEnabled(checked)
        }

        RowButton {
            id: resumeRow

            last: true
            visible: Hyprsunset.overridden
            icon: "restart_alt"
            text: Tr.tr("Resume schedule")
            subtext: Tr.tr("Drop the manual change and follow the schedule again")
            onClicked: Hyprsunset.resumeSchedule()
        }

        SectionHeader {
            text: Tr.tr("Colour temperature")
        }

        SliderRow {
            first: true
            last: true
            icon: "thermostat"
            label: Tr.tr("Warmth")
            valueLabel: Tr.tr("%1K").arg(Hyprsunset.temperature)
            value: (Hyprsunset.maxTemperature - Hyprsunset.temperature) / root.tempRange
            onMoved: v => Hyprsunset.setTemperature(Hyprsunset.maxTemperature - v * root.tempRange)
        }

        SectionHeader {
            text: Tr.tr("Schedule")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Automatic schedule")
            subtext: Tr.tr("Turn on and off at set times. Switching by hand lasts until the next change.")
            checked: Hyprsunset.automatic
            onToggled: Hyprsunset.setAutomatic(checked)
        }

        TextFieldRow {
            label: Tr.tr("Turn on at")
            errorText: Tr.tr("Must be a 24 hour time, e.g. 20:00")
            value: GlobalConfig.services.nightLight.from
            placeholderText: "20:00"
            maximumLength: 5
            smallField: true
            validate: root.timePattern
            onEditingFinished: value => {
                if (field.valid)
                    GlobalConfig.services.nightLight.from = value;
            }
        }

        TextFieldRow {
            last: true
            label: Tr.tr("Turn off at")
            errorText: Tr.tr("Must be a 24 hour time, e.g. 08:00")
            value: GlobalConfig.services.nightLight.to
            placeholderText: "08:00"
            maximumLength: 5
            smallField: true
            validate: root.timePattern
            onEditingFinished: value => {
                if (field.valid)
                    GlobalConfig.services.nightLight.to = value;
            }
        }

        SectionHeader {
            text: Tr.tr("About")
        }

        InfoRow {
            first: true
            last: true
            icon: "info"
            label: Tr.tr("Powered by hyprsunset")
            subtext: Tr.tr("Lower temperatures are warmer (more red), higher are cooler (more blue)")
            value: Hyprsunset.available ? (Hyprsunset.active ? Tr.tr("Running") : Tr.tr("Stopped")) : Tr.tr("Not installed")
        }
    }
}

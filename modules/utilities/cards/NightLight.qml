import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

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
                    text: Hyprsunset.active ? qsTr("Active • %1K").arg(Config.services.nightLight.colorTemperature) : qsTr("Screen at normal temperature")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }

            StyledSwitch {
                checked: Hyprsunset.active
                onToggled: Hyprsunset.toggle(checked)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Hyprsunset.active
            spacing: Appearance.spacing.small

            opacity: Hyprsunset.active ? 1 : 0

            Behavior on opacity {
                Anim {}
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: qsTr("Temperature")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: `${Config.services.nightLight.colorTemperature}K`
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3primary
                    font.weight: 500
                }
            }

            StyledSlider {
                Layout.fillWidth: true
                Layout.topMargin: -Appearance.spacing.small

                from: 1200
                to: 6500
                value: Config.services.nightLight.colorTemperature
                onMoved: Config.services.nightLight.colorTemperature = value
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: -Appearance.spacing.small

                StyledText {
                    text: qsTr("Warm")
                    color: Colours.palette.m3outline
                    font.pointSize: Appearance.font.size.smaller
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: qsTr("Cool")
                    color: Colours.palette.m3outline
                    font.pointSize: Appearance.font.size.smaller
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Hyprsunset.active
            spacing: Appearance.spacing.normal

            opacity: Hyprsunset.active ? 1 : 0

            Behavior on opacity {
                Anim {}
            }

            MaterialIcon {
                text: "schedule"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.normal
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Automatic mode")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledSwitch {
                checked: Config.services.nightLight.automatic
                onToggled: Config.services.nightLight.automatic = checked
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: -Appearance.spacing.small
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

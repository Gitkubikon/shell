pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property Session session

    anchors.fill: parent

    StyledFlickable {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large * 2

        flickableDirection: Flickable.VerticalFlick
        contentHeight: content.height

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right

            spacing: Appearance.spacing.large

            // Header
            StyledText {
                text: qsTr("Night Light")
                font.pointSize: Appearance.font.size.extraLarge
                font.weight: 600
            }

            StyledText {
                Layout.topMargin: -Appearance.spacing.large
                text: qsTr("Reduces blue light to reduce eye strain during night hours")
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.normal
                wrapMode: Text.WordWrap
            }

            // Enable Toggle
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.normal

                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: "bedtime"
                    color: Colours.palette.m3onSurface
                    font.pointSize: Appearance.font.size.larger
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Enable now")
                    font.pointSize: Appearance.font.size.normal
                }

                StyledSwitch {
                    checked: Hyprsunset.active
                    onToggled: Hyprsunset.toggle(checked)
                }
            }

            StyledText {
                Layout.topMargin: Appearance.spacing.normal
                Layout.leftMargin: Appearance.font.size.larger + Appearance.spacing.normal
                text: qsTr("Automatically enable between %1 and %2").arg(Config.services.nightLight.from).arg(Config.services.nightLight.to)
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.small
                wrapMode: Text.WordWrap
                visible: Config.services.nightLight.automatic
            }

            // Temperature Slider
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.large

                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: qsTr("Color Temperature")
                        font.pointSize: Appearance.font.size.normal
                        font.weight: 500
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: `${Config.services.nightLight.colorTemperature}K`
                        color: Colours.palette.m3primary
                        font.pointSize: Appearance.font.size.normal
                        font.weight: 500
                    }
                }

                StyledSlider {
                    Layout.fillWidth: true

                    from: 1200
                    to: 6500
                    value: Config.services.nightLight.colorTemperature
                    onMoved: Config.services.nightLight.colorTemperature = value
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: qsTr("Warm")
                        color: Colours.palette.m3outline
                        font.pointSize: Appearance.font.size.small
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: qsTr("Cool")
                        color: Colours.palette.m3outline
                        font.pointSize: Appearance.font.size.small
                    }
                }
            }

            // Schedule Settings (only shown when automatic is enabled)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.large
                visible: Config.services.nightLight.automatic
                spacing: Appearance.spacing.normal

                StyledText {
                    text: qsTr("Schedule")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        Layout.minimumWidth: 80
                        text: qsTr("From")
                        font.pointSize: Appearance.font.size.normal
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: fromField.implicitHeight + Appearance.padding.normal * 2

                        color: Colours.tPalette.m3surfaceContainerHigh
                        radius: Appearance.rounding.small

                        StyledTextField {
                            id: fromField

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal

                            text: Config.services.nightLight.from
                            placeholderText: "19:00"
                            onAccepted: Config.services.nightLight.from = text
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        Layout.minimumWidth: 80
                        text: qsTr("To")
                        font.pointSize: Appearance.font.size.normal
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: toField.implicitHeight + Appearance.padding.normal * 2

                        color: Colours.tPalette.m3surfaceContainerHigh
                        radius: Appearance.rounding.small

                        StyledTextField {
                            id: toField

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal

                            text: Config.services.nightLight.to
                            placeholderText: "06:30"
                            onAccepted: Config.services.nightLight.to = text
                        }
                    }
                }
            }

            // Info section
            StyledRect {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.large
                implicitHeight: infoContent.implicitHeight + Appearance.padding.large * 2

                color: Colours.tPalette.m3surfaceContainerHighest
                radius: Appearance.rounding.normal

                RowLayout {
                    id: infoContent

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large

                    spacing: Appearance.spacing.normal

                    MaterialIcon {
                        text: "info"
                        color: Colours.palette.m3primary
                        font.pointSize: Appearance.font.size.larger
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Night Light uses hyprsunset to adjust screen color temperature. Lower values are warmer (more red), higher values are cooler (more blue).")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.small
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    Component.onCompleted: {
        Hyprsunset.fetchState();
    }
}

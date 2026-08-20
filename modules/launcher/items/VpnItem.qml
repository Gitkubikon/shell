import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property VpnServers.Server modelData
    required property var list

    readonly property string country: modelData?.country ?? ""
    readonly property string city: modelData?.city ?? ""
    readonly property string protocol: modelData?.protocol ?? ""
    readonly property bool isVirtual: modelData?.isVirtual ?? false

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.modelData?.onClicked(root.list)
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.medium

        spacing: Tokens.spacing.medium

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "vpn_key"
            fontStyle: Tokens.font.icon.extraLarge
            color: Colours.palette.m3onSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.city || root.modelData?.name || ""
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    const parts = [];
                    if (root.country)
                        parts.push(root.country);
                    if (root.protocol)
                        parts.push(root.protocol);
                    if (root.isVirtual)
                        parts.push(qsTr("Virtual"));
                    return parts.join(" • ");
                }
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        StyledRect {
            Layout.alignment: Qt.AlignVCenter

            visible: root.protocol !== ""
            color: root.protocol === "UDP" ? Colours.palette.m3tertiary : Colours.palette.m3secondaryContainer
            radius: Tokens.rounding.medium
            implicitWidth: protocolLabel.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: protocolLabel.implicitHeight + Tokens.padding.small

            StyledText {
                id: protocolLabel

                anchors.centerIn: parent
                text: root.protocol
                color: root.protocol === "UDP" ? Colours.palette.m3onTertiary : Colours.palette.m3onSecondaryContainer
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
            }
        }
    }
}

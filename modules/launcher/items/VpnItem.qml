import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property VpnServers.Server modelData
    required property var list

    readonly property string country: modelData?.country ?? ""
    readonly property string city: modelData?.city ?? ""
    readonly property string protocol: modelData?.protocol ?? ""
    readonly property bool isVirtual: modelData?.isVirtual ?? false

    implicitHeight: Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Appearance.rounding.normal

        function onClicked(): void {
            root.modelData?.onClicked(root.list);
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.larger

        spacing: Appearance.spacing.normal

        MaterialIcon {
            text: "vpn_key"
            font.pointSize: Appearance.font.size.extraLarge
            Layout.alignment: Qt.AlignVCenter
            color: Colours.palette.m3onSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                text: root.city || root.modelData?.name || ""
                color: Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            StyledText {
                text: {
                    let parts = [];
                    if (root.country) parts.push(root.country);
                    if (root.protocol) parts.push(root.protocol);
                    if (root.isVirtual) parts.push("Virtual");
                    return parts.join(" • ");
                }
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        StyledRect {
            visible: root.protocol !== ""
            color: root.protocol === "UDP" ? Colours.palette.m3tertiary : Colours.palette.m3secondaryContainer
            radius: Appearance.rounding.small
            implicitWidth: protocolLabel.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: protocolLabel.implicitHeight + Appearance.padding.small * 2
            Layout.alignment: Qt.AlignVCenter

            StyledText {
                id: protocolLabel
                anchors.centerIn: parent
                text: root.protocol
                color: root.protocol === "UDP" ? Colours.palette.m3onTertiary : Colours.palette.m3onSecondaryContainer
                font.pointSize: Appearance.font.size.small
                font.weight: 600
            }
        }
    }
}

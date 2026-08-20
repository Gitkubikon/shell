import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var list
    required property var modelData

    // Safely handle modelData to prevent errors during transitions
    readonly property string safeModelData: (modelData && typeof modelData === "string") ? modelData : ""
    readonly property bool isPreset: safeModelData !== "main" && safeModelData !== ""
    readonly property string input: isPreset ? safeModelData : list.search.text.slice(`${GlobalConfig.launcher.actionPrefix}passgen`.length).trim()

    property string generated: ""
    property string activeConfig: ""
    property string type: "password"
    property int length: 32

    readonly property string iconName: {
        if (type === "uuid")
            return "fingerprint";
        if (type === "hex")
            return "tag";
        if (type === "pin" || type === "numeric")
            return "pin";
        if (type === "base64")
            return "code";
        if (type === "alpha")
            return "abc";
        return "key";
    }

    function generate(): void {
        const parts = root.input.split(/\s+/);

        let newType = "password";
        let newLength = 32;
        let noSymbols = false;
        let noAmbiguous = false;
        let upper = false;
        let lower = false;
        let urlSafe = false;

        for (const part of parts) {
            if (part === "")
                continue;
            if (part.startsWith("-")) {
                const flag = part.replace(/^-+/, "").toLowerCase();
                if (flag === "no-symbols" || flag === "ns")
                    noSymbols = true;
                else if (flag === "no-ambiguous" || flag === "na")
                    noAmbiguous = true;
                else if (flag === "upper" || flag === "u")
                    upper = true;
                else if (flag === "lower" || flag === "l")
                    lower = true;
                else if (flag === "url-safe" || flag === "s")
                    urlSafe = true;
            } else if (!isNaN(part)) {
                newLength = parseInt(part);
            } else {
                const t = part.toLowerCase();
                if (["hex", "base64", "pin", "numeric", "alpha", "uuid", "password"].includes(t))
                    newType = t;
            }
        }

        if (newType === "hex" && !root.input.match(/\b\d+\b/))
            newLength = 16;
        if (newType === "uuid")
            newLength = 36;
        if (newLength < 1)
            newLength = 1;
        if (newLength > 128)
            newLength = 128;

        root.type = newType;
        root.length = newLength;

        let result = "";

        if (newType === "uuid") {
            result = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
                const r = Math.random() * 16 | 0;
                const v = c === "x" ? r : (r & 0x3 | 0x8);
                return v.toString(16);
            });
            root.activeConfig = qsTr("UUID v4");
        } else {
            let chars = "";
            if (newType === "hex") {
                chars = "0123456789abcdef";
                root.activeConfig = qsTr("Hex (%1 bits)").arg(newLength * 8);
            } else if (newType === "base64") {
                chars = urlSafe ? "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_" : "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
                root.activeConfig = urlSafe ? qsTr("Base64 (URL safe)") : qsTr("Base64");
            } else if (newType === "pin" || newType === "numeric") {
                chars = "0123456789";
                root.activeConfig = qsTr("PIN / Numeric");
            } else if (newType === "alpha") {
                chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
                root.activeConfig = qsTr("Alphanumeric");
            } else {
                chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
                if (!noSymbols)
                    chars += "!@#$%^&*()_+-=[]{}|;:,.<>?";
                root.activeConfig = qsTr("Password");
            }

            if (noAmbiguous)
                chars = chars.replace(/[0O1lI]/g, "");
            if (upper)
                chars = chars.toUpperCase();
            if (lower)
                chars = chars.toLowerCase();

            chars = Array.from(new Set(chars.split(""))).join("");

            if (chars.length === 0) {
                result = qsTr("Error: No characters left");
            } else {
                for (let i = 0; i < newLength; i++)
                    result += chars.charAt(Math.floor(Math.random() * chars.length));
                if (newType === "base64" && !urlSafe)
                    result += "=".repeat((4 - (result.length % 4)) % 4);
            }
        }

        root.generated = result;
    }

    function onClicked(): void {
        Quickshell.execDetached(["wl-copy", root.generated]);
        root.list.screenState.launcher = false;
    }

    onInputChanged: generate()
    onModelDataChanged: generate()
    Component.onCompleted: generate()

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.onClicked()
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.medium

        spacing: Tokens.spacing.medium

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: root.iconName
            fontStyle: Tokens.font.icon.extraLarge
            color: root.isPreset ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.generated
                color: Colours.palette.m3onSurface
                font: Tokens.font.mono.medium
                elide: Text.ElideLeft
            }

            StyledText {
                Layout.fillWidth: true
                text: root.isPreset ? `${root.activeConfig} (${root.input})` : qsTr("%1 • %2 chars").arg(root.activeConfig).arg(root.generated.length)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        StyledRect {
            Layout.alignment: Qt.AlignVCenter

            color: Colours.palette.m3tertiary
            radius: Tokens.rounding.large
            clip: true

            implicitWidth: (stateLayer.containsMouse ? label.implicitWidth + label.anchors.rightMargin : 0) + icon.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: Math.max(label.implicitHeight, icon.implicitHeight) + Tokens.padding.small

            StateLayer {
                id: stateLayer

                color: Colours.palette.m3onTertiary
                onClicked: root.onClicked()
            }

            StyledText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: icon.left
                anchors.rightMargin: Tokens.spacing.small

                text: qsTr("Copy")
                color: Colours.palette.m3onTertiary
                font: Tokens.font.label.medium

                opacity: stateLayer.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            MaterialIcon {
                id: icon

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.medium

                text: "content_copy"
                color: Colours.palette.m3onTertiary
                fontStyle: Tokens.font.icon.large
            }

            Behavior on implicitWidth {
                Anim {
                    type: Anim.Emphasized
                }
            }
        }
    }
}

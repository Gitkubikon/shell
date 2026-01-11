import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var list
    required property var modelData

    // Safely handle modelData to prevent errors during transitions
    readonly property string safeModelData: (modelData && typeof modelData === "string") ? modelData : ""
    readonly property bool isPreset: safeModelData !== "main" && safeModelData !== ""
    readonly property string input: isPreset ? safeModelData : list.search.text.slice(`${Config.launcher.actionPrefix}passgen`.length).trim()

    property string generated: ""
    property string activeConfig: ""
    property string type: "password"
    property int length: 32

    readonly property string iconName: {
        if (type === "uuid") return "fingerprint"
        if (type === "hex") return "tag"
        if (type === "pin" || type === "numeric") return "pin"
        if (type === "base64") return "code"
        if (type === "alpha") return "abc"
        return "key"
    }

    function generate() {
        // If input is empty in main mode, default to standard password
        let effectiveInput = input
        // ... rest of generation logic (parts splitting etc) is dependent on effectiveInput which is now safe-ish
        // But if transition is happening and modelData is object, input depends on search text.
        // Search text is likely ">passgen " or something.
        if (!isPreset && input.length === 0) {
            // Defaults processed below handles empty string ok
        }

        let parts = effectiveInput.split(/\s+/)

        let newType = "password"
        let newLength = 32
        let noSymbols = false
        let noAmbiguous = false
        let upper = false
        let lower = false
        let urlSafe = false

        for (let part of parts) {
            if (part === "") continue;
            if (part.startsWith("--") || part.startsWith("-")) {
                let flag = part.replace(/^-+/, "").toLowerCase()
                if (flag === "no-symbols" || flag === "ns") noSymbols = true
                else if (flag === "no-ambiguous" || flag === "na") noAmbiguous = true
                else if (flag === "upper" || flag === "u") upper = true
                else if (flag === "lower" || flag === "l") lower = true
                else if (flag === "url-safe" || flag === "s") urlSafe = true
            } else if (!isNaN(part)) {
                newLength = parseInt(part)
            } else {
                let t = part.toLowerCase()
                if (["hex", "base64", "pin", "numeric", "alpha", "uuid", "password"].includes(t)) {
                    newType = t
                }
            }
        }

        if (newType === "hex" && !effectiveInput.match(/\b\d+\b/)) newLength = 16
        if (newType === "uuid") newLength = 36
        if (newLength < 1) newLength = 1
        if (newLength > 128) newLength = 128

        // Update state
        root.type = newType
        root.length = newLength
        // ... (rest of logic handles generation result)

        let result = ""

        if (newType === "uuid") {
            result = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(c) {
                var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
                return v.toString(16);
            });
            root.activeConfig = "UUID v4"
        } else {
            let chars = ""
            if (newType === "hex") {
                chars = "0123456789abcdef"
                root.activeConfig = `Hex (${newLength * 8} bits)`
            } else if (newType === "base64") {
                chars = urlSafe ? "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
                                : "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
                root.activeConfig = `Base64${urlSafe ? " (URL safe)" : ""}`
            } else if (newType === "pin" || newType === "numeric") {
                chars = "0123456789"
                root.activeConfig = "PIN / Numeric"
            } else if (newType === "alpha") {
                chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
                root.activeConfig = "Alphanumeric"
            } else {
                chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
                if (!noSymbols) chars += "!@#$%^&*()_+-=[]{}|;:,.<>?"
                root.activeConfig = "Password"
            }

            if (noAmbiguous) chars = chars.replace(/[0O1lI]/g, "")
            if (upper) chars = chars.toUpperCase()
            if (lower) chars = chars.toLowerCase()

            chars = Array.from(new Set(chars.split(''))).join('')

            if (chars.length === 0) {
                result = "Error: No characters left"
            } else {
                for (let i = 0; i < newLength; i++) {
                    result += chars.charAt(Math.floor(Math.random() * chars.length))
                }
                if (newType === "base64" && !urlSafe) {
                    let padding = (4 - (result.length % 4)) % 4
                    result += "=".repeat(padding)
                }
            }
        }

        root.generated = result
    }

    onInputChanged: generate()
    Component.onCompleted: generate()

    // Using `modelData` changes to trigger regen for presets is safe because they are static
    onModelDataChanged: generate()

    function onClicked(): void {
        Quickshell.execDetached(["wl-copy", root.generated]);
        // Only close if it's the main item or explicitly requested?
        // Standard launcher behavior is close on action.
        root.list.visibilities.launcher = false;
    }

    implicitHeight: Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Appearance.rounding.normal

        function onClicked(): void {
            root.onClicked();
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.larger

        spacing: Appearance.spacing.normal

        MaterialIcon {
            text: root.iconName
            font.pointSize: Appearance.font.size.extraLarge
            Layout.alignment: Qt.AlignVCenter
            color: root.isPreset ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                id: result
                
                color: Colours.palette.m3onSurface
                text: root.generated
                elide: Text.ElideLeft
                font.family: Appearance.font.family.mono

                Layout.fillWidth: true
            }

            StyledText {
                text: root.isPreset ? `${root.activeConfig} (${root.input})` : `${root.activeConfig} • ${root.generated.length} chars`
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        StyledRect {
            color: Colours.palette.m3tertiary
            radius: Appearance.rounding.normal
            clip: true

            implicitWidth: (stateLayer.containsMouse ? label.implicitWidth + label.anchors.rightMargin : 0) + icon.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: Math.max(label.implicitHeight, icon.implicitHeight) + Appearance.padding.small * 2

            Layout.alignment: Qt.AlignVCenter

            StateLayer {
                id: stateLayer

                color: Colours.palette.m3onTertiary

                function onClicked(): void {
                    root.onClicked();
                }
            }

            StyledText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: icon.left
                anchors.rightMargin: Appearance.spacing.small

                text: qsTr("Copy")
                color: Colours.palette.m3onTertiary
                font.pointSize: Appearance.font.size.normal

                opacity: stateLayer.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            MaterialIcon {
                id: icon

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal

                text: "content_copy"
                color: Colours.palette.m3onTertiary
                font.pointSize: Appearance.font.size.large
            }

            Behavior on implicitWidth {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
        }
    }
}

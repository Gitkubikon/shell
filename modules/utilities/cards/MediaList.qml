pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

/**
 * Generic file browser used by the Media card for both screenshots and recordings.
 * Follows upstream's RecordingList behaviour (FileSystemModel with sortReverse,
 * animated expand/collapse, animated empty placeholder) but is parameterised so
 * one component serves both tabs.
 */
ColumnLayout {
    id: root

    required property var props
    required property ScreenState screenState
    // Display
    required property string title
    required property string emptyText
    required property string itemText // Must contain a single %1 for the timestamp
    required property string emptyIcon
    // Data
    required property string path
    required property list<string> nameFilters
    required property string filePrefix // Filename prefix, e.g. "screenshot"
    // Actions
    required property string openIcon
    required property list<string> openApp
    required property string confirmDeleteProp // props key holding the pending delete path

    readonly property bool expanded: root.props.mediaListExpanded

    spacing: 0

    // Quickshell.Widgets' WrapperMouseArea: a MouseArea sized to its child row.
    // Do not shadow it with a local plain Item wrapper; that has no implicit
    // height, so the list below ends up drawn over this header.
    WrapperMouseArea {
        Layout.fillWidth: true

        cursorShape: Qt.PointingHandCursor
        onClicked: root.props.mediaListExpanded = !root.props.mediaListExpanded

        RowLayout {
            spacing: Tokens.spacing.medium

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: "list"
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                text: root.title
                font: Tokens.font.body.medium
            }

            IconButton {
                icon: root.expanded ? "unfold_less" : "unfold_more"
                type: IconButton.Text
                label.animate: true
                onClicked: root.props.mediaListExpanded = !root.props.mediaListExpanded
            }
        }
    }

    StyledListView {
        id: list

        model: FileSystemModel {
            path: root.path
            nameFilters: root.nameFilters
            sortReverse: true // Names are timestamped, so reverse sort is newest first
        }

        Layout.fillWidth: true
        Layout.rightMargin: -Tokens.spacing.small
        implicitHeight: (Tokens.font.body.large.pointSize + Tokens.padding.small) * (root.expanded ? 10 : 3)
        clip: true

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: list
        }

        delegate: RowLayout {
            id: entry

            required property FileSystemEntry modelData
            property string baseName

            anchors.left: list.contentItem.left
            anchors.right: list.contentItem.right
            anchors.rightMargin: Tokens.spacing.small
            spacing: Tokens.spacing.extraSmall

            Component.onCompleted: baseName = modelData.baseName

            StyledText {
                Layout.fillWidth: true
                Layout.rightMargin: Tokens.spacing.extraSmall
                text: {
                    const name = entry.baseName;
                    const matches = name.match(new RegExp(`^${root.filePrefix}_(\\d{4})(\\d{2})(\\d{2})_(\\d{2})-(\\d{2})-(\\d{2})`, "i"));
                    if (!matches)
                        return name;
                    const date = new Date(...matches.slice(1));
                    date.setMonth(date.getMonth() - 1); // Woe (months start from 0)
                    return root.itemText.arg(Qt.formatDateTime(date, Qt.locale()));
                }
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            IconButton {
                icon: root.openIcon
                type: IconButton.Text
                onClicked: {
                    root.screenState.utilities = false;
                    root.screenState.sidebar = false;
                    Quickshell.execDetached([...root.openApp, entry.modelData.path]);
                }
            }

            IconButton {
                icon: "folder"
                type: IconButton.Text
                onClicked: {
                    root.screenState.utilities = false;
                    root.screenState.sidebar = false;
                    Quickshell.execDetached([...GlobalConfig.general.apps.explorer, entry.modelData.path]);
                }
            }

            IconButton {
                icon: "delete_forever"
                type: IconButton.Text
                label.color: Colours.palette.m3error
                stateLayer.color: Colours.palette.m3error
                onClicked: {
                    if (Config.utilities.confirmDelete)
                        root.props[root.confirmDeleteProp] = entry.modelData.path;
                    else
                        CUtils.deleteFile(Qt.resolvedUrl(entry.modelData.path));
                }
            }
        }

        add: Transition {
            Anim {
                type: Anim.DefaultEffects
                property: "opacity"
                from: 0
                to: 1
            }
        }

        remove: Transition {
            Anim {
                type: Anim.DefaultEffects
                property: "opacity"
                to: 0
            }
        }

        displaced: Transition {
            Anim {
                type: Anim.DefaultEffects
                property: "opacity"
                to: 1
            }
            Anim {
                property: "y"
            }
        }

        Loader {
            asynchronous: true
            anchors.centerIn: parent

            opacity: list.count === 0 ? 1 : 0
            active: opacity > 0

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.emptyIcon
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.extraLarge

                    opacity: root.expanded ? 1 : 0
                    scale: root.expanded ? 1 : 0
                    Layout.preferredHeight: root.expanded ? implicitHeight : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on scale {
                        Anim {}
                    }

                    Behavior on Layout.preferredHeight {
                        Anim {}
                    }
                }

                RowLayout {
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.emptyIcon
                        color: Colours.palette.m3outline

                        opacity: root.expanded ? 0 : 1
                        scale: root.expanded ? 0 : 1
                        Layout.preferredWidth: root.expanded ? 0 : implicitWidth

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        Behavior on scale {
                            Anim {}
                        }

                        Behavior on Layout.preferredWidth {
                            Anim {}
                        }
                    }

                    StyledText {
                        text: root.emptyText
                        color: Colours.palette.m3outline
                    }
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Behavior on implicitHeight {
            Anim {}
        }
    }
}

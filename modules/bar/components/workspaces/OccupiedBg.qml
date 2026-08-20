pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.config

Item {
    id: root

    required property Repeater workspaces
    required property var occupied
    required property int groupOffset

    property list<var> pills: []

    function updatePills() {
        if (!occupied)
            return;
        
        let count = 0;
        const newPills = [...pills];
        const start = groupOffset;
        const end = start + Config.bar.workspaces.shown;
        
        for (const [ws, occ] of Object.entries(occupied)) {
            if (ws > start && ws <= end && occ) {
                const isFirstInGroup = Number(ws) === start + 1;
                if (isFirstInGroup || !occupied[ws - 1]) {
                    if (newPills[count]) {
                        newPills[count].start = ws;
                    } else {
                        newPills.push(pillComp.createObject(root, {
                            start: ws
                        }));
                    }
                    count++;
                }
                if ((Number(ws) === end || !occupied[Number(ws) + 1]) && newPills[count - 1])
                    newPills[count - 1].end = ws;
            }
        }
        
        if (newPills.length > count) {
            newPills.splice(count, newPills.length - count).forEach(p => p.destroy());
        }
        
        root.pills = newPills;
    }

    onOccupiedChanged: updatePills()
    onGroupOffsetChanged: updatePills()

    Repeater {
        model: ScriptModel {
            values: root.pills.filter(p => p)
        }

        StyledRect {
            id: rect

            required property var modelData

            readonly property Workspace start: root.workspaces.count > 0 ? root.workspaces.itemAt(getWsIdx(modelData.start)) ?? null : null // qmllint disable incompatible-type
            readonly property Workspace end: root.workspaces.count > 0 ? root.workspaces.itemAt(getWsIdx(modelData.end)) ?? null : null // qmllint disable incompatible-type

            function getWsIdx(ws: int): int {
                let i = ws - 1;
                while (i < 0)
                    i += Config.bar.workspaces.shown;
                return i % Config.bar.workspaces.shown;
            }

            anchors.horizontalCenter: root.horizontalCenter

            y: (start?.y ?? 0) - 1
            implicitWidth: Config.bar.sizes.innerWidth - Appearance.padding.small * 2 + 2
            implicitHeight: start && end ? end.y + end.size - start.y + 2 : 0

            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
            radius: Appearance.rounding.full

            scale: 0
            Component.onCompleted: scale = 1

            Behavior on scale {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }

            Behavior on y {
                Anim {}
            }

            Behavior on implicitHeight {
                Anim {}
            }
        }
    }

    Component {
        id: pillComp

        Pill {}
    }

    component Pill: QtObject {
        property int start
        property int end
    }
}

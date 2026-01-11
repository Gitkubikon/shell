pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.effects
import qs.services // for Colours
import qs.services as Services
import qs.config
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQuick.Effects
import "calendar_layout.js" as CalendarLayout

Item {
    id: root

    required property var state

    readonly property int firstDay: {
        const cfg = Config.services && Config.services.calendarFirstDayOfWeek;
        const value = Math.max(0, Math.min(6, cfg === undefined || cfg === null ? 0 : cfg));
        return value;
    }
    readonly property date viewDate: state?.currentDate
                                      ? new Date(state.currentDate.getFullYear(), state.currentDate.getMonth(), 1)
                                      : new Date()
    readonly property var calendarLayout: buildCalendar(viewDate, isCurrentMonth(viewDate), firstDay)
    readonly property var selectedEvents: Services.Calendar.eventsOn(state?.currentDate ?? new Date())
                                              .sort((a, b) => a.startDate - b.startDate)
    property bool overlayVisible: false
    property date overlayDate: state?.currentDate ?? new Date()
    property var overlayEvents: []
    readonly property real gridSpacing: Appearance.spacing.smaller
    readonly property int gridRows: Math.max(1, calendarLayout ? calendarLayout.length : 6)
    readonly property real widthBasedCellSize: Math.max(36, (content.width - gridSpacing * 6) / 7)
    readonly property real heightAvailableForGrid: {
        const availableHeight = calendarBody.height || root.height || (root.parent ? root.parent.height : 0);
        if (availableHeight <= 0)
            return 0;
        const margins = Appearance.padding.large * 2;
        const headers = monthRow.implicitHeight + weekdayRow.implicitHeight;
        const spacers = content.spacing * 2; // spacing above/below gridWrapper
        return Math.max(0, availableHeight - margins - headers - spacers);
    }
    readonly property real heightBasedCellSize: {
        const free = heightAvailableForGrid - gridSpacing * (gridRows - 1);
        return free > 0 ? Math.max(36, free / gridRows) : widthBasedCellSize;
    }
    readonly property real cellSize: Math.min(Math.min(widthBasedCellSize, heightBasedCellSize), 60)

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: content.implicitHeight + Appearance.padding.large * 2

    WheelHandler {
        target: null
        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.state.currentDate = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1);
            else if (event.angleDelta.y < 0)
                root.state.currentDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            root.state.currentDate = new Date();
        }
    }

    function isCurrentMonth(d) {
        const now = new Date();
        return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
    }

    function buildCalendar(date, highlight, firstDayOfWeek) {
        if (CalendarLayout && CalendarLayout.getCalendarLayout) {
            const layout = CalendarLayout.getCalendarLayout(date, highlight, firstDayOfWeek) || [];
            return layout;
        }

        // Fallback: minimal calendar layout so the UI still renders if the script import fails.
        const base = date ? new Date(date) : new Date();
        const today = new Date();
        const first = Math.max(0, Math.min(6, firstDayOfWeek || 0));
        const year = base.getFullYear();
        const month = base.getMonth();
        const firstOfMonth = new Date(year, month, 1);
        const mondayBased = (firstOfMonth.getDay() + 6) % 7; // JS Sunday=0, make Monday=0
        const startOffset = (mondayBased - first + 7) % 7;
        const startDate = new Date(year, month, 1 - startOffset);

        const calendar = [...Array(6)].map(() => Array(7));
        for (let i = 0; i < 6; i++) {
            for (let j = 0; j < 7; j++) {
                const cellDate = new Date(startDate);
                cellDate.setDate(startDate.getDate() + i * 7 + j);

                const inMonth = cellDate.getMonth() === month;
                const isToday = cellDate.getDate() === today.getDate()
                    && cellDate.getMonth() === today.getMonth()
                    && cellDate.getFullYear() === today.getFullYear();

                calendar[i][j] = {
                    day: cellDate.getDate(),
                    month: cellDate.getMonth(),
                    year: cellDate.getFullYear(),
                    inMonth,
                    today: isToday ? 1 : inMonth ? 0 : -1,
                };
            }
        }
        return calendar;
    }

    function toDate(cell) {
        if (!cell || cell.day === "" || cell.year === undefined || cell.month === undefined)
            return state?.currentDate ?? new Date();
        return new Date(cell.year, cell.month, cell.day);
    }

        function openEventsOverlay(cellItem) {
            const targetCell = cellItem && cellItem.safeCell ? cellItem.safeCell : null;
            const targetDate = targetCell ? toDate(targetCell) : state?.currentDate ?? new Date();

            if (!state?.currentDate) {
                state.currentDate = targetDate;
            }

            if (targetCell && targetCell.day !== "") {
                state.currentDate = targetDate;
            }

            // Reset and repopulate overlay data to avoid stale/mingled entries
            overlayVisible = false;
            overlayEvents = [];
            overlayDate = new Date(targetDate);
            overlayEvents = Services.Calendar.eventsOn(targetDate)
                                    .map(e => ({
                                        title: e.title,
                                        content: e.content,
                                        summary: e.summary,
                                        startDate: e.startDate,
                                        endDate: e.endDate,
                                        startIso: e.startIso,
                                        endIso: e.endIso,
                                        color: e.color
                                    }))
                                    .sort((a, b) => a.startDate - b.startDate);
            overlayVisible = true;
        }

        Item {
            id: calendarBody

            anchors.fill: parent

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: Appearance.padding.large
                spacing: Appearance.spacing.normal

            RowLayout {
                id: monthRow
                Layout.fillWidth: true

                spacing: Appearance.spacing.small

                Item {
                    implicitWidth: implicitHeight
                    implicitHeight: prevMonthIcon.implicitHeight + Appearance.padding.small * 2

                    StateLayer {
                        id: prevMonthState

                        radius: Appearance.rounding.full
                        function onClicked() {
                            root.state.currentDate = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1);
                        }
                    }

                    MaterialIcon {
                        id: prevMonthIcon

                        anchors.centerIn: parent
                        text: "chevron_left"
                        color: Colours.palette.m3tertiary
                        font.pointSize: Appearance.font.size.normal
                        font.weight: 700
                    }
                }

                StyledText {
                    Layout.fillWidth: true

                    text: Qt.formatDate(viewDate, "MMMM yyyy")
                    horizontalAlignment: Text.AlignHCenter
                    color: Colours.palette.m3primary
                    font.pointSize: Appearance.font.size.normal
                    font.weight: 600

                    StateLayer {
                        anchors.fill: parent
                        anchors.margins: -Appearance.padding.small
                        radius: Appearance.rounding.full
                        disabled: isCurrentMonth(viewDate)

                        function onClicked() {
                            root.state.currentDate = new Date();
                        }
                    }
                }

                Item {
                    implicitWidth: implicitHeight
                    implicitHeight: nextMonthIcon.implicitHeight + Appearance.padding.small * 2

                    StateLayer {
                        id: nextMonthState

                        radius: Appearance.rounding.full
                        function onClicked() {
                            root.state.currentDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1);
                        }
                    }

                    MaterialIcon {
                        id: nextMonthIcon

                        anchors.centerIn: parent
                        text: "chevron_right"
                        color: Colours.palette.m3tertiary
                        font.pointSize: Appearance.font.size.normal
                        font.weight: 700
                    }
                }
            }

            RowLayout {
                id: weekdayRow
                Layout.fillWidth: true
                spacing: root.gridSpacing

                Repeater {
                    model: (CalendarLayout && CalendarLayout.getWeekDays)
                               ? CalendarLayout.getWeekDays(firstDay)
                               : [
                                   { day: "Mo", today: 0 },
                                   { day: "Tu", today: 0 },
                                   { day: "We", today: 0 },
                                   { day: "Th", today: 0 },
                                   { day: "Fr", today: 0 },
                                   { day: "Sa", today: 0 },
                                   { day: "Su", today: 0 },
                               ]

                    delegate: StyledText {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: root.cellSize
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.day
                        horizontalAlignment: Text.AlignHCenter
                        font.weight: 600
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            ColumnLayout {
                id: gridWrapper

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.gridSpacing
                Layout.preferredHeight: root.cellSize * root.gridRows + root.gridSpacing * (root.gridRows - 1)

                Repeater {
                    model: calendarLayout || []

                    delegate: RowLayout {
                        required property var modelData

                        readonly property var week: modelData

                        Layout.fillWidth: true
                        spacing: root.gridSpacing
                        Layout.preferredHeight: root.cellSize

                        Repeater {
                            model: week ? week.length : 0

                            delegate: DayCell {
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredWidth: root.cellSize
                                Layout.alignment: Qt.AlignHCenter

                                cell: week ? week[index] : null
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: overlayLayer

            anchors.fill: parent
            visible: overlayVisible
            z: 9999

            StyledRect {
                id: overlayCard

                anchors.fill: parent
                radius: Appearance.rounding.large
                color: "transparent"

                ShaderEffectSource {
                    id: blurSource
                    sourceItem: calendarBody
                    visible: false
                    live: overlayVisible
                }

                // Blurred Background
                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: overlayCard.width
                            height: overlayCard.height
                            radius: overlayCard.radius
                            visible: false
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: blurSource
                        blurEnabled: true
                        blur: 64
                        saturation: -0.1
                    }

                    // High opacity tint to hide sharp text
                    Rectangle {
                        anchors.fill: parent
                        color: Colours.palette.m3surfaceContainerHigh
                        opacity: 0.95
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller

                        MaterialIcon {
                            text: "event_note"
                            color: Colours.palette.m3primary
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 700
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: Qt.formatDate(overlayDate ?? new Date(), "dddd, dd MMM yyyy")
                                font.weight: 700
                                color: Colours.palette.m3onSurface
                                wrapMode: Text.Wrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const count = overlayEvents.length;
                                    return count === 1 ? qsTr("1 event") : qsTr("%1 events").arg(count);
                                }
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }

                        Item { Layout.fillWidth: true }

                        IconButton {
                            id: closeButton
                            type: IconButton.Tonal
                            icon: "close"
                            padding: Appearance.padding.smaller
                            font.pointSize: Appearance.font.size.normal
                            implicitHeight: Math.max(34, label.implicitHeight + padding * 2)
                            onClicked: overlayVisible = false
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: Services.Calendar.loading || !Services.Calendar.khalAvailable
                        spacing: Appearance.spacing.smaller

                        BusyIndicator {
                            visible: Services.Calendar.loading
                            running: visible
                            width: 18
                            height: 18
                        }

                        StyledText {
                            text: qsTr("Refreshing events…")
                            color: Colours.palette.m3onSurfaceVariant
                            font.weight: 600
                            visible: Services.Calendar.loading
                        }

                        StyledText {
                            text: Services.Calendar.errorMessage || qsTr("Calendar backend not available")
                            color: Colours.palette.m3error
                            font.weight: 600
                            visible: !Services.Calendar.khalAvailable
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        sourceComponent: !Services.Calendar.khalAvailable
                                           ? backendErrorComponent
                                           : (overlayEvents.length === 0 ? overlayEmptyComponent : overlayEventsListComponent)
                    }
                }
            }
        }
    Component {
        id: backendErrorComponent

        Item {
            anchors.fill: parent

            StyledText {
                anchors.centerIn: parent
                text: Services.Calendar.errorMessage || qsTr("Install/configure Caelestia calendar to show events")
                color: Colours.palette.m3error
                font.weight: 600
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Component {
        id: overlayEmptyComponent

        Item {
            anchors.fill: parent

            StyledText {
                anchors.centerIn: parent
                text: Services.Calendar.loading ? qsTr("Loading events…") : qsTr("No events for this day")
                color: Colours.palette.m3onSurfaceVariant
                font.weight: 600
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

        Component {
            id: overlayEventsListComponent

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    id: eventsColumn

                    width: parent.width - Appearance.padding.normal
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.spacing.small

                    Repeater {
                        model: overlayEvents ? overlayEvents.slice(0) : []

                        delegate: StyledRect {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: innerRow.implicitHeight + Appearance.padding.small * 2
                            radius: Appearance.rounding.small
                            color: Colours.palette.m3surfaceContainerHighest

                            RowLayout {
                                id: innerRow
                                anchors.fill: parent
                                anchors.margins: Appearance.padding.small
                                spacing: Appearance.spacing.small

                                // Color Indicator Strip
                                Rectangle {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 4
                                    radius: 2
                                    color: modelData.color || Colours.palette.m3primary
                                    opacity: 0.9
                                }

                                // Content Column
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: {
                                            if (modelData && modelData.title && modelData.title.length) return modelData.title;
                                            if (modelData && modelData.summary && modelData.summary.length) return modelData.summary;
                                            return qsTr("Untitled event");
                                        }
                                        wrapMode: Text.Wrap
                                        color: Colours.palette.m3onSurface
                                        font.weight: 600
                                        font.pointSize: Appearance.font.size.normal
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        StyledText {
                                            text: {
                                                const d = modelData && modelData.startDate ? new Date(modelData.startDate) : null;
                                                return d && !isNaN(d) ? Qt.formatDateTime(d, Config.services.useTwelveHourClock ? "hh:mm AP" : "hh:mm") : "";
                                            }
                                            font.weight: 500
                                            font.pointSize: Appearance.font.size.smaller
                                            color: Colours.palette.m3onSurfaceVariant
                                        }

                                        StyledText {
                                            text: "-"
                                            visible: timeEnd.visible
                                            font.pointSize: Appearance.font.size.smaller
                                            color: Colours.palette.m3onSurfaceVariant
                                        }

                                        StyledText {
                                            id: timeEnd
                                            text: {
                                                const d = modelData && modelData.endDate ? new Date(modelData.endDate) : null;
                                                return d && !isNaN(d) ? Qt.formatDateTime(d, Config.services.useTwelveHourClock ? "hh:mm AP" : "hh:mm") : "";
                                            }
                                            font.pointSize: Appearance.font.size.smaller
                                            color: Colours.palette.m3onSurfaceVariant
                                            visible: modelData.endDate && modelData.startDate && modelData.endDate !== modelData.startDate
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    component DayCell: Item {
        id: dayCell

        required property var cell

        readonly property date currentDateVal: state?.currentDate ?? new Date()
        readonly property date todayMidnight: {
            const d = new Date();
            d.setHours(0, 0, 0, 0);
            return d;
        }
        readonly property var safeCell: (cell && cell.day !== undefined)
                                        ? cell
                                        : ({ day: "", month: viewDate.getMonth(), year: viewDate.getFullYear(), today: -1 })
        readonly property bool isToday: safeCell.today === 1
        readonly property bool inMonth: safeCell.inMonth !== undefined
                                        ? safeCell.inMonth
                                        : (safeCell.today >= 0 || safeCell.month === viewDate.getMonth())
        readonly property bool isSelected: {
            const d = toDate(safeCell);
            const curr = currentDateVal;
            return d && curr
                && d.getDate() === curr.getDate()
                && d.getMonth() === curr.getMonth()
                && d.getFullYear() === curr.getFullYear();
        }
        readonly property date cellDate: toDate(safeCell)
        readonly property int temporalState: {
            if (!cellDate) return 0;
            if (cellDate.getTime() < todayMidnight.getTime()) return -1; // past
            if (cellDate.getTime() > todayMidnight.getTime()) return 1; // future
            return 0; // today
        }
        readonly property var events: safeCell.day === ""
                                      ? []
                                      : Services.Calendar.eventsOn(toDate(safeCell))
        readonly property color eventColor: dayCell.events.length > 0
                                            ? (dayCell.events[0]?.color || Colours.palette.m3primary)
                                            : Colours.palette.m3primary
        readonly property bool isPast: dayCell.temporalState < 0

                implicitWidth: root.cellSize
                implicitHeight: root.cellSize

                StyledRect {
                    id: bg
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Appearance.rounding.small

                    color: dayCell.isSelected
                               ? Colours.palette.m3primaryContainer
                               : (dayCell.isToday
                                      ? Colours.layer(Colours.palette.m3secondaryContainer, 0.3)
                                      : "transparent")

                    border.width: (dayCell.isToday && !dayCell.isSelected) ? 1 : 0
                    border.color: Colours.palette.m3primary

                    opacity: (!dayCell.isSelected && !dayCell.isToday && dayCell.isPast) ? 0.5 : 1

                    Item {
                        anchors.fill: parent
                        anchors.margins: Appearance.padding.small

                        Text {
                            anchors.centerIn: parent
                            text: `${safeCell.day}`
                            font.weight: (dayCell.isSelected || dayCell.isToday) ? Font.Bold : Font.Normal
                            color: dayCell.isSelected
                                   ? Colours.palette.m3onPrimaryContainer
                                   : (dayCell.isToday
                                          ? Colours.palette.m3primary
                                          : (dayCell.inMonth
                                                 ? Colours.palette.m3onSurface
                                                 : Colours.palette.m3onSurfaceVariant))
                            font.pointSize: Appearance.font.size.normal
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        spacing: 3
                        visible: dayCell.events.length > 0

                        property int maxDots: 4
                        property int dotCount: Math.min(maxDots, dayCell.events.length)

                        Repeater {
                            model: parent.dotCount
                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: dayCell.isSelected
                                       ? Colours.palette.m3onPrimaryContainer
                                       : (dayCell.events[index]?.color || Colours.palette.m3primary)
                            }
                        }
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colours.palette.m3onSurface
                        opacity: hover.hovered ? 0.05 : 0
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onTapped: {
                            const dt = toDate(safeCell);
                            openEventsOverlay(dayCell);
                        }
                    }
                }    }
}
}

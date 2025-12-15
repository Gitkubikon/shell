// Lightly adapted from the reference sidebar calendar to support custom first-day-of-week
// and driving a 6x7 grid layout.
const weekDays = [
	{ day: "Mo", today: 0 },
	{ day: "Tu", today: 0 },
	{ day: "We", today: 0 },
	{ day: "Th", today: 0 },
	{ day: "Fr", today: 0 },
	{ day: "Sa", today: 0 },
	{ day: "Su", today: 0 },
];

function checkLeapYear(year) {
	return year % 400 === 0 || (year % 4 === 0 && year % 100 !== 0);
}

function getMonthDays(month, year) {
	const leapYear = checkLeapYear(year);
	if ((month <= 7 && month % 2 === 1) || (month >= 8 && month % 2 === 0))
		return 31;
	if (month === 2 && leapYear) return 29;
	if (month === 2 && !leapYear) return 28;
	return 30;
}

function getNextMonthDays(month, year) {
	const leapYear = checkLeapYear(year);
	if (month === 1 && leapYear) return 29;
	if (month === 1 && !leapYear) return 28;
	if (month === 12) return 31;
	if ((month <= 7 && month % 2 === 1) || (month >= 8 && month % 2 === 0))
		return 30;
	return 31;
}

function getPrevMonthDays(month, year) {
	const leapYear = checkLeapYear(year);
	if (month === 3 && leapYear) return 29;
	if (month === 3 && !leapYear) return 28;
	if (month === 1) return 31;
	if ((month <= 7 && month % 2 === 1) || (month >= 8 && month % 2 === 0))
		return 30;
	return 31;
}

function getCalendarLayout(dateObject, highlight, firstDayOfWeek) {
	const base = dateObject ? new Date(dateObject) : new Date();
	const today = new Date();

	// firstDayOfWeek: 0 = Monday (matches weekDays order), 6 = Sunday
	const first = Math.max(
		0,
		Math.min(
			6,
			firstDayOfWeek === undefined || firstDayOfWeek === null
				? 0
				: firstDayOfWeek,
		),
	);

	const year = base.getFullYear();
	const month = base.getMonth(); // zero-indexed
	const firstOfMonth = new Date(year, month, 1);
	const mondayBased = (firstOfMonth.getDay() + 6) % 7; // convert JS Sunday=0 to Monday=0
	const startOffset = (mondayBased - first + 7) % 7;
	const startDate = new Date(year, month, 1 - startOffset);

	const calendar = [...Array(6)].map(() => Array(7));
	for (let i = 0; i < 6; i++) {
		for (let j = 0; j < 7; j++) {
			const cellDate = new Date(startDate);
			cellDate.setDate(startDate.getDate() + i * 7 + j);

			const inMonth = cellDate.getMonth() === month;
			const isToday =
				cellDate.getDate() === today.getDate() &&
				cellDate.getMonth() === today.getMonth() &&
				cellDate.getFullYear() === today.getFullYear();

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

function getWeekDays(firstDayOfWeek) {
	const first = Math.max(
		0,
		Math.min(
			6,
			firstDayOfWeek === undefined || firstDayOfWeek === null
				? 0
				: firstDayOfWeek,
		),
	);
	return weekDays.map((_, i) => weekDays[(i + first) % 7]);
}

function getDateInXMonthsTime(x, baseDate) {
	const currentDate = baseDate ? new Date(baseDate) : new Date();
	if (x === 0) return currentDate;

	let targetMonth = currentDate.getMonth() + x;
	let targetYear = currentDate.getFullYear();

	targetYear += Math.floor(targetMonth / 12);
	targetMonth = ((targetMonth % 12) + 12) % 12;

	return new Date(targetYear, targetMonth, 1);
}

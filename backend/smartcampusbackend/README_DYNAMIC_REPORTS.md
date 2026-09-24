# Dynamic Reports Update

Added `GET /api/reports/day` to the existing reports controller.

Example:
`/api/reports/day?day=MONDAY&academicYear=2026-2027&semesterNo=1`

Response includes:
- timetable: scheduled slots for the selected weekday
- bookings: confirmed bookings whose booking date falls on the selected weekday
- bookingCount
- timetableCount

Existing summary/export endpoints and all timetable/occupancy/booking functionality are preserved.

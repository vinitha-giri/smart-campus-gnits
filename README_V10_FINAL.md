# GNITS Smart Campus V10 – DB-driven capacities + full Live Occupancy

This build is based on the V8/V9 project line and keeps the year-level timetable replacement/deletion flow, block labels, Campus Map removal, hosted-backend settings, and occupancy performance fixes.

## Capacity source of truth
The application no longer applies a hardcoded GNITS room-capacity policy at runtime. APIs return `rooms.capacity` exactly as stored in MySQL. Update room capacities in the database/Admin Room Management; the UI reads the stored value.

Requested database values:
- A002 = 320
- F306 = 200
- F105 = 180
- all LAB = 75
- all E-Classroom = 120
- IT Seminar Hall = 180

The `database/apply_gnits_capacity_standards.sql` file is a one-time migration/repair helper only; it is not used by the application at runtime.

## Live Occupancy
`GET /api/rooms/live-status` loads the complete `rooms` table and calculates status from timetable + confirmed bookings. The Flutter screen then applies only the user's Class type / Block / Capacity filters. It now displays the actual room type (Classroom, Laboratory, E-Classroom, Seminar Hall, Conference Hall) instead of labeling every non-hall room as Classroom.

If a user selects `100+`, labs with capacity 75 will correctly disappear. Select `Any capacity` to see every room returned by the API.

The Rooms screen similarly loads the complete room list from `GET /api/rooms/availability`.

## Capacity filter thresholds
Both Live Occupancy and Book a Classroom use:
- Any capacity
- 70+ seats
- 140+ seats
- 210+ seats
- 280+ seats
- 350+ seats

## Timetable lifecycle
Admin Timetable supports:
- Upload/update one workbook containing multiple section sheets.
- Whole-year replacement: validate the workbook first, then replace only the selected 1st/2nd/3rd/4th year for the selected academic year + semester.
- Whole-year deletion after a semester is completed.
- Individual section deletion remains available as a narrower option.

## Production deployment
Firebase Hosting is configured to publish:
`frontend/smart_campus_app/build/web`

Production Flutter build:
`flutter build web --release --dart-define=API_BASE_URL=https://gnits-smart-campus-api.onrender.com`

Firebase deployment:
`firebase deploy --only hosting`

# GNITS Smart Campus V10

This version keeps the existing V8/V9 feature set and fixes database-driven capacity handling and Live Occupancy presentation.

## Capacity source of truth
Room capacities are read directly from `rooms.capacity` in MySQL. There is no application-level hardcoded GNITS capacity policy in the backend. The database should contain:
- A002 = 320
- F306 = 200
- F105 = 180
- LAB = 75
- E-Classroom = 120
- IT Seminar Hall = 180

## Live Occupancy
The backend returns the full `rooms` catalogue and calculates current status from timetable + confirmed bookings. The UI applies only the selected class type, block, and capacity filters. Room cards now display the real room type (Classroom, Laboratory, E-Classroom, Seminar Hall, Conference Hall).

## Booking capacity filters
Available room filters use: Any capacity, 70+, 140+, 210+, 280+, 350+.

## Timetable management
Year-level replacement/deletion remains available in Admin -> Timetable. Whole-year replacement validates the workbook before replacing only the selected year/semester.

## Deployment
Flutter Hosting directory: `frontend/smart_campus_app/build/web`.
Backend API: `https://gnits-smart-campus-api.onrender.com` when using the production dart-define.

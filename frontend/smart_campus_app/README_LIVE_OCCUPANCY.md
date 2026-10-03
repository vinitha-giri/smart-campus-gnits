# GNITS Smart Campus – Live Occupancy

## What is included

- Live Occupancy navigation for Admin, Faculty and Student.
- `/api/occupancy/live` authoritative live snapshot.
- Timetable + confirmed booking + maintenance/reserved status calculation.
- WebSocket refresh events with polling fallback.
- Future-date booking availability fix.
- Excel multi-sheet timetable upload with per-row room mapping.
- Room resolution by exact room number, normalized room number, and `lecture_hall_mapping`.
- Flexible GNITS time parsing, including schedules written as `01:00-02:00` for afternoon periods and `12:10-1:10`.

## Important occupancy behavior

"Occupied" means **scheduled/booking occupancy**, not physical people detection. A room becomes OCCUPIED when the selected/current day and time falls inside an uploaded timetable event for that room. A confirmed booking is shown as BOOKED unless a timetable event takes precedence.

## Excel upload behavior

The importer reads all non-instruction sheets, preserves each sheet's YEAR-DEPARTMENT-SECTION key, maps each row to its own LH-No/Room, and stores each subject/time interval as a timetable entry. Blank template sheets are ignored.

The importer understands common GNITS headers such as:
- `09:00-10:00`
- `11:10-12:10`
- `12:10-1:10`
- `01:00-02:00`
- `01:20-02:20`

For ambiguous 1–6 clock values without AM/PM, the importer uses the surrounding morning sequence to interpret the afternoon periods correctly.

## Physical occupancy

Actual people-in-room occupancy requires IoT sensors, RFID/attendance, Wi-Fi/device detection, or another physical data source. The current application does not claim to measure physical presence.


## Live Occupancy Filters
The Live Occupancy screen now supports client-side filtering without changing the existing occupancy/timetable logic: class type (Classroom, Lab, Seminar Hall, Conference), block (A, B, C, D, F, S), and minimum capacity (30+, 50+, 75+, 100+). Filters work in both LIVE NOW and selected timetable-slot modes, update the summary counts, and include a Clear action.

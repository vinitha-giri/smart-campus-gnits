# GNITS Smart Campus - Enterprise Excel + Reports Update

## Multi-sheet Excel
The endpoint `POST /api/timetable/excel/upload` now reads every `.xlsx` sheet except `Instructions`, `Read Me`, `Notes`, and `Summary`.

Recommended sheet naming:
- CSE-A
- CSE-B
- CSE-C
- CSE-D

Each sheet must contain:
`Day | 9:00-10:00 | 10:00-11:00 | 11:10-12:10 | 1:00-2:00 | 2:00-3:00 | 3:00-4:00 | LH-No`

The sheet name becomes the section name. A sheet named `Timetable` uses the `sectionName` request parameter.

Validation is all-or-nothing. Every room is resolved against `rooms.room_no`, duplicate room/time slots are rejected, and conflicts with other sections are rejected before existing data is replaced.

## Reports
`GET /api/reports/summary?academicYear=2026-2027&semesterNo=1`

Returns total rooms, operational rooms, scheduled slots, utilization percentage, section count, subject count, day-wise scheduled slots, and top utilized rooms.

## Flutter
- Enterprise-style operations dashboard
- Live occupancy page
- Multi-sheet timetable upload page
- Reports page
- Automatic occupancy refresh every 15 seconds


## Timetable management improvements (August 2026)

- `GET /api/timetable/excel/sections?academicYear=2026-2027&semesterNo=1` returns only sections actually stored for the selected term.
- `DELETE /api/timetable/excel/section?sectionName=CSE-D&academicYear=2026-2027&semesterNo=1` deletes only that section for that term.
- Re-uploading a workbook safely replaces only the sections present in that workbook for the selected term, after all validation succeeds.
- The Flutter admin screen uses the sections endpoint; section names are not hard-coded into the UI.

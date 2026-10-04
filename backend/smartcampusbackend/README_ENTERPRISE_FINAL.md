# GNITS Smart Campus - Enterprise Backend Update

## Preserved APIs/features
- Timetable Excel processing and multi-sheet upload
- Room APIs
- Occupancy APIs
- Booking APIs
- Reports and Excel export

## Logic improvements
- `/api/occupancy/slots` reads time intervals directly from timetable data instead of hard-coding slots.
- `/api/occupancy` checks timetable and confirmed bookings.
- `/api/rooms/availability` returns live state, current activity, available-from and available-until/next-occupied information.
- `/api/reports/summary` returns filter-aware scheduled-today, active-now, bookings-today, available-now and current-utilization metrics.
- `/api/reports/day` filters timetable data by academic year, semester and section and returns bookings for the next occurrence of the selected weekday.
- `/api/reports/export` applies the same filters.

## Build note
The source was checked for balanced Java/Dart delimiters. A full Maven/Flutter build should be run on the development machine where the project dependencies are installed.


### Section-aware timetable behavior

- Select the **academic year** and **semester** before downloading or managing a timetable.
- The Excel download is a **starter workbook**; its example section sheets are not a fixed master list.
- Admin can **delete unused sheets** (for example, remove CSE-B if that section does not exist for that year/semester).
- Admin can add or rename sheets for sections that actually exist. The sheet name is stored as the section name.
- Uploading the same section again replaces only that section for the selected academic year + semester.
- Deleting a section from the Admin UI removes only that section for the selected academic year + semester.
- The UI section list is loaded from stored timetable data; it does not hard-code CSE-A/B/C/D.

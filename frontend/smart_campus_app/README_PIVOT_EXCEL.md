# Smart Campus - Pivot Excel Timetable

## Admin flow
1. Login as Admin (`admin` / `admin123`).
2. Open **Timetable**.
3. Enter Section, Academic Year and Semester.
4. Click **Download / Open Excel Template**.
5. Fill subjects in the time-slot cells and enter the physical room number in **LH-No**.
6. Upload the `.xlsx` file.

### Excel format
`Day | 9:00-10:00 | 10:00-11:00 | 11:10-12:10 | 1:00-2:00 | 2:00-3:00 | 3:00-4:00 | LH-No`

If a day uses multiple rooms, add another row for that day with the second LH-No.

## Occupancy
Open **Room Occupancy**, choose a day and time slot, and the app calls `/api/occupancy`. Every room is shown as AVAILABLE, OCCUPIED, MAINTENANCE or RESERVED. OCCUPIED cards show subject, section and time.

## Backend
Spring Boot runs on port 8080. For an Android emulator the Flutter app uses `10.0.2.2:8080`; for Chrome/desktop it uses `localhost:8080`.

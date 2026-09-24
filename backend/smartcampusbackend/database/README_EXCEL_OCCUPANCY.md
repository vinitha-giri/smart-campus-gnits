# GNITS Smart Campus - Excel Timetable + Occupancy

## What was changed

### Flutter
- Admin dashboard now has a **Timetable / Admin** card.
- Admin can enter Section, Academic Year and Semester.
- **Download / Open Excel Template** opens a generated `.xlsx` file.
- The Excel template contains Monday-Saturday and the GNITS timetable slots:
  - 09:00-10:00
  - 10:00-11:00
  - 11:10-12:10
  - 12:10-13:00
  - 13:00-14:00
  - 14:00-15:00
  - 15:00-16:00
- Admin fills `LH No` and `Subject Code / Name` for occupied slots.
- Admin uploads the completed `.xlsx`.
- A new **Room Occupancy** screen lets users select Day + Time Slot and see OCCUPIED / AVAILABLE / MAINTENANCE / RESERVED.
- Occupancy refreshes automatically every 15 seconds.
- Removed `dart:html`; the upload screen now uses `url_launcher`, so the project is not web-only.

### Spring Boot
- Excel template generation was generalized; it is no longer locked to CSE-D / C-301.
- Excel upload uses **LH No -> rooms.room_no** to find the correct room.
- Empty prefilled day/time rows are ignored.
- Partially-filled rows are rejected.
- Invalid days/times and unknown LH numbers are rejected before DB changes.
- Duplicate room/time entries inside the uploaded Excel are rejected.
- Existing timetable for the selected section + academic year + semester is replaced only after validation.
- A room conflict against another section is rejected.
- Added `/api/occupancy?day=MONDAY&time=09:00` for the Flutter occupancy screen.

## Run order

### 1. Database
Make sure MySQL is running and `smart_campus_db` exists.

Check:
`database/timetable_occupancy_verification.sql`

The `timetable_entries` table must contain:
- `room_id`
- `lh_no`
- `day_of_week`
- `start_time`
- `end_time`
- `academic_year`
- `semester_no`
- `section_name`
- `subject_name`

If `lh_no` or `subject_name` is missing, uncomment and run the corresponding ALTER statements in the SQL file.

### 2. Backend
Open a terminal inside:

`smartcampusbackend`

Check `src/main/resources/application.properties`:
- MySQL database: `smart_campus_db`
- username: `root`
- password: `password`
- port: `8080`

Then run:

`mvnw.cmd spring-boot:run`

or, if Maven is installed:

`mvn spring-boot:run`

The API should be available at:

`http://localhost:8080`

### 3. Flutter
Open a terminal inside:

`smart_campus_app`

Run:

`flutter pub get`

Then:

`flutter run -d chrome`

The Flutter app expects the backend at:

`http://localhost:8080`

If you run Flutter on an Android emulator, change `ApiConfig.baseUrl` in
`lib/upload_timetable_screen.dart` and use `http://10.0.2.2:8080`.

## Test the complete flow

1. Start MySQL.
2. Start Spring Boot.
3. Start Flutter.
4. Login as:
   - Role: Admin
   - Username: `admin`
   - Password: `admin123`
5. Open **Timetable**.
6. Enter `CSE-A`, `2026-2027`, semester `1`.
7. Click **Download / Open Excel Template**.
8. In Excel, for example, fill:
   - Monday
   - 09:00-10:00
   - LH No: `C-301`
   - Subject: `CNS`
   - Section: `CSE-A`
9. Save as `.xlsx`.
10. Choose the file in Flutter.
11. Click **Validate & Upload Timetable**.
12. Open **Room Occupancy**.
13. Select Monday + `09:00 - 10:00`.
14. `C-301` should show **OCCUPIED** with `CNS` and `CSE-A`.
15. Select another time slot and the room becomes **AVAILABLE** if no class is scheduled.

## Important
The Excel `LH No` must match the `room_no` value already stored in the `rooms` table. This prevents the same physical room from being represented by unrelated room IDs in the timetable.

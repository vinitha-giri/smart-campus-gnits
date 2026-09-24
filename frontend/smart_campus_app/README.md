# GNITS Smart Campus Flutter App

This version includes:
- Admin timetable Excel download/upload
- GNITS day/time-slot template
- LH No based room mapping
- Live room occupancy by selected day/time
- Automatic occupancy refresh
- Cross-platform file picker and URL launcher

Run:

```bash
flutter pub get
flutter run -d chrome
```

Backend default:
`http://localhost:8080`

Admin demo:
- Username: `admin`
- Password: `admin123`

For Android emulator, set `ApiConfig.baseUrl` in
`lib/upload_timetable_screen.dart` to `http://10.0.2.2:8080`.

## Booking roles
- Admin: admin / admin123
- Faculty: faculty / faculty123
- Student: student / student123

Only Admin and Faculty receive the Book a Room workspace. Booking checks timetable conflicts and existing confirmed bookings through the Spring Boot API.

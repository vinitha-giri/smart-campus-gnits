# GNITS Smart Campus – Responsive Enterprise UI Update

## Preserved functionality
- Role-based Admin / Faculty / Student login
- Timetable Excel template and multi-sheet upload
- Timetable validation and section deletion/replacement
- Live occupancy
- Room management/search
- Room booking for Admin and Faculty
- Booking conflict checks
- My bookings / Admin all bookings
- Reports export

## UI improvements
- Responsive desktop/tablet/mobile layout
- Collapsible desktop sidebar: icons remain visible; hover expands labels
- Tooltip labels while sidebar is collapsed
- Mobile navigation drawer with full labels
- Clickable global room/class search
- Dashboard Available Rooms KPI opens booking for Admin/Faculty and room search for Student
- Dashboard Occupied Rooms KPI opens Live Occupancy
- Dashboard quick actions for finding rooms
- My bookings is displayed above Available Rooms in the booking page

## Dynamic reports
The Reports & Analytics screen now calls:
- GET /api/reports/summary
- GET /api/reports/day?day=MONDAY&academicYear=2026-2027&semesterNo=1
- GET /api/reports/export

Clicking Monday/Tuesdays/etc. loads the timetable slots for that day and confirmed room bookings that fall on that weekday.

## Flutter source organization
- main.dart – application bootstrap/theme
- app_theme.dart – shared colors
- api_config.dart – backend URL selection
- auth_screens.dart – splash/login
- dashboard_shell.dart – responsive navigation/sidebar/search
- common_widgets.dart – shared UI components
- overview_screen.dart – dashboard
- occupancy_screen.dart – live occupancy
- rooms_screen.dart – room search
- booking_screen.dart – booking workflow
- upload_timetable_screen.dart – Excel timetable workflow
- reports_screen.dart – dynamic reports

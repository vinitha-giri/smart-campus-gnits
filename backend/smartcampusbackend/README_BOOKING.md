# GNITS Smart Campus — Room Booking

## Booking authority
- Admin: `admin / admin123`
- Faculty: `faculty / faculty123`
- Student: `student / student123`

Only Admin and Faculty can create/cancel bookings. Students can still use the existing Rooms and Live Occupancy modules.

## How availability works
A room is shown as available only when:
1. the room is not administratively marked MAINTENANCE or RESERVED,
2. no timetable entry overlaps the requested time on that date's weekday, and
3. no confirmed room booking overlaps the requested time/date.

## Backend endpoints
- `GET /api/bookings/available?date=YYYY-MM-DD&startTime=HH:mm&endTime=HH:mm&capacity=60`
- `GET /api/bookings?role=ADMIN&username=admin`
- `GET /api/bookings?role=FACULTY&username=faculty`
- `POST /api/bookings`
- `DELETE /api/bookings/{id}?role=ADMIN&username=admin`

## Database
The backend uses `spring.jpa.hibernate.ddl-auto=update` so the `room_bookings` table is created automatically during development without deleting existing tables/data. An explicit migration is also included at `migrations/003_room_bookings.sql` for controlled database deployment.

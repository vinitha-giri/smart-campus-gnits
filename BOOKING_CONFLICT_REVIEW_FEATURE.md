# Booking priority conflict review

This update adds a separate workflow for requesting review of an already approved booking. It does not weaken the existing availability check, booking overlap protection, or approval process.

## User flow
- Faculty opens **Conflict Reviews** in the dashboard and selects another faculty member's approved booking.
- Faculty submits P1 (Critical), P2 (High), P3 (Normal), or P4 (Routine) plus a justification.
- The system notifies the requesting department Head Staff and the department that owns the approved booking. If both faculty are in the same department, one Head Staff decision satisfies both department checks.
- Each distinct department must agree before the request moves to Admin.
- Admin records one of: keep existing booking, alternate room, alternate time, mutual reschedule, or escalate.
- Both faculty receive in-app/push/email notifications at submission, Head Staff decision, and Admin resolution.

## Safety guarantees
- Conflict requests are stored in their own `booking_conflict_requests` table.
- Submitting or approving a conflict review does not reserve a room, cancel a booking, or edit the original booking.
- The original confirmed booking continues to block overlapping bookings.
- Admin resolution is recorded as an audited decision/note; any actual room/time change must be performed through the existing authorized booking process after coordination. No automatic displacement occurs.
- Hibernate `ddl-auto=update` creates the new table without requiring a destructive migration.

## API
- `POST /api/booking-conflicts` — faculty submits `{username, existingBookingId, priority, justification}`.
- `GET /api/booking-conflicts/candidates?username=...` — approved bookings that the faculty member may challenge.
- `GET /api/booking-conflicts?role=...&emailAddress=...` — role-scoped review list.
- `POST /api/booking-conflicts/{id}/head-decision?emailAddress=...` — Head Staff body `{decision: AGREE|DECLINE}`.
- `POST /api/booking-conflicts/{id}/admin-resolution?emailAddress=...` — Admin body `{resolution, note}`.

The endpoints follow the identity-by-email/username pattern already used by this project's booking APIs. This is consistent with the current project architecture; it is not a replacement for a future server-enforced authenticated principal/authorization layer.

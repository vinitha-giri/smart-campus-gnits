# GNITS Smart Campus – conflict workflow additions (V3 source update)

This source update extends the V2 priority conflict workflow while preserving the existing Flutter screens and backend endpoints.

## Added in this update

- Faculty may submit a conflict review against another faculty member's `PENDING_APPROVAL` or `CONFIRMED` booking. Rejected/cancelled bookings are not eligible.
- Duplicate open reviews for the same requester and booking are rejected.
- Head Staff can verify/correct the requested P1–P4 priority; the verifier and timestamp are stored.
- Separate `booking_conflict_audit` records are written for submission, Head Staff decisions, priority verification, consent, reminders, escalation, booking movement and Admin resolution.
- Both faculty participants can record/withdraw consent for mutual rescheduling.
- Admin can move the existing confirmed booking to a different room or time. Mutual rescheduling requires both participants' consent.
- The backend validates the target room, time ordering and room overlap before changing the booking. A failed availability check leaves the booking unchanged.
- Conflict review reminder is sent at 30 minutes. Unresolved reviews are escalated to Admin after two hours. These jobs run every five minutes.
- If the underlying booking is rejected, cancelled or deleted while a review is open, the review is closed and participants are notified.
- The Flutter Conflict Reviews screen now supports pending-booking selection, priority verification, consent, Admin target details and audit history.

## API additions

- `POST /api/booking-conflicts/{id}/priority-verification?emailAddress=...` body `{ "priority": "P1" }`
- `POST /api/booking-conflicts/{id}/consent?emailAddress=...` body `{ "agree": true }`
- `GET /api/booking-conflicts/{id}/history?emailAddress=...`
- Admin resolution accepts optional target fields: `targetRoomId`, `targetDate` (`YYYY-MM-DD`), `targetStartTime` and `targetEndTime` (`HH:mm`). `ALTERNATE_ROOM` requires `targetRoomId`; `ALTERNATE_TIME` requires date and times; `MUTUAL_RESCHEDULE` requires room, date, times and both consents.

## Database

The backend uses Hibernate `ddl-auto=update`; the new audit table and entity columns are added non-destructively at application startup. Back up the production database before deploying any schema-changing release.

## Important verification and security notes

- This environment did not have Maven or Flutter/Dart SDKs available, and the uploaded Maven wrapper is missing `.mvn/wrapper/maven-wrapper.properties`. Therefore Maven compilation, Flutter analysis/build and end-to-end tests could not be run here. Run those checks locally before deployment.
- Existing project endpoints identify users using email/username request parameters. This update retains that existing architecture; it does **not** introduce signed server sessions/JWT authentication. Do not treat role checks based only on caller-supplied identity as production-grade authentication. Add/verify authenticated principals before public production exposure.
- For a pending original booking, Admin cannot move it through this resolution endpoint until it becomes `CONFIRMED`; the normal approver must first approve or reject it. If rejected/cancelled, the review is closed by the scheduled service.

# GNITS Smart Campus V5 – Booking workflow source patch

This source update is based on `GNITS_SMART_CAMPUS_CONFLICT_REVIEW_V3_SOURCE_UPDATE.zip`.

## Changes in this patch

1. The embedded **My booking activity** section in Book a Classroom now displays status-aware records rather than an unconditional Cancel action. It shows up to five recent records, labels pending/approved/rejected/cancelled/completed states, and only offers cancellation for future pending or approved bookings. The separate My Bookings screen was not intentionally changed.
2. The booking availability response now includes `unavailableRooms` for overlapping pending/confirmed bookings, with booking ID, room, date/time, purpose, status, requester identity/name and department. Available rooms remain in the existing `rooms` field for backward compatibility.
3. Book a Classroom renders unavailable bookings separately and provides a Request priority review action for another faculty member's booking. It opens Conflict Reviews with the competing booking preselected.
4. Backend cancellation rejects already-started/past bookings and terminal statuses, retains the booking row as CANCELLED, publishes a room-change event, and creates in-app/email/push cancellation notifications for the booking owner and department Head Staff.

## Important limitations – not a production sign-off

This patch does **not** complete every item in the four-batch production roadmap. In particular:
- The existing API still accepts caller-supplied role/username/email in multiple endpoints. Server-side session-token/JWT authentication and authorization must be implemented consistently before public use.
- Concurrent booking race protection needs a database-level locking/constraint strategy and load/concurrency tests. The existing transactional pre-check alone is not sufficient proof against simultaneous requests.
- Cancellation reason capture, full immutable booking-event audit, notification delivery/outbox retries, and complete rescheduling transaction guarantees still require implementation/verification.
- The existing conflict-review/reminder/escalation features are retained, but all department-crossing, timeout, consent, and failure cases require integration tests.
- Room maintenance, calendar, analytics, backups, rate limiting, and operational monitoring are not newly implemented by this patch.

## Verification

The ZIP archive is structurally checked. This environment does not have Flutter/Dart or Maven installed, and the supplied Maven wrapper configuration is incomplete, so Flutter analysis/build and Maven tests could not be run here. Treat this as a source patch for local validation, not a build-verified or production-ready release.

## Suggested local checks

1. Run backend tests/build with the project's configured JDK and Maven.
2. Run `flutter pub get`, `dart format` on the changed Dart files, `flutter analyze`, and `flutter build web`.
3. Test pending and approved bookings from two faculty accounts, including overlapping times.
4. Verify cancelled bookings remain in history but no longer block availability.
5. Verify cancellation notices reach the booking owner and department Head Staff.
6. Test the conflict review action from the unavailable room card and verify the correct booking is preselected.
7. Test concurrent booking submissions from separate clients before any production deployment.

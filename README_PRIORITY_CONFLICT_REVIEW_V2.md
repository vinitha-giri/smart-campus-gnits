GNITS Smart Campus – Priority Conflict Review V2

Changes in this package:
- Head Staff can submit classroom booking requests; their own requests route to Admin.
- Head Staff retains department-scoped approval authority for Faculty requests.
- Faculty and Head Staff can view their own bookings.
- Room schedule events for confirmed bookings now include the booking owner's display name and department so another faculty member can identify who booked the room.
- Existing conflict-review workflow from the supplied V1 project is retained.

Important implementation status:
This is not yet a production-complete implementation of every item in the original conflict-resolution plan. Automated 30-minute / 2-hour conflict reminders, automatic Admin escalation, verified-priority tracking, actual alternate-room/time rescheduling, and server-session-based authorization for the conflict endpoints remain outstanding. Admin resolution currently records the decision and note; it does not modify either booking.

Build verification:
The ZIP archive can be integrity-checked, but a Maven build could not be run in this environment because the supplied Maven wrapper is missing .mvn/wrapper/maven-wrapper.properties and system Maven/Flutter SDKs are unavailable. Test locally before deployment.

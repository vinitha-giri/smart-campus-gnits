# GNITS Smart Campus — Batch 2: Faculty Booking Approval

## What changed
- Faculty classroom bookings now create `PENDING_APPROVAL` requests.
- The backend finds the first `HEAD_STAFF` account in the faculty member's department.
- The Head Staff receives a persistent in-app notification and sees an `Approval Requests` page.
- Head Staff can approve or reject a request and optionally provide a rejection reason.
- On approval, the booking becomes `CONFIRMED` and the faculty member receives a persistent notification.
- On rejection, the booking becomes `REJECTED` and the faculty member receives a persistent notification.
- Pending requests are treated as occupied for availability checks so two users cannot request the same room/time simultaneously.
- Admin bookings remain immediately `CONFIRMED`.
- Student booking remains disabled.
- Admin Manage Users can create a `HEAD_STAFF` account with department mapping.
- Notifications are stored in MySQL and are loaded when the Notifications screen opens.

## Important
This batch implements the approval workflow and persistent in-app notifications. Phone push notifications (Firebase Cloud Messaging) and automatic reminders are the next batch.

## Database
The project uses `spring.jpa.hibernate.ddl-auto=update`, so the new entity/columns should be created on startup. The SQL migration is included as `database/batch2_booking_approval.sql` for deployments where schema changes are managed manually.

## Test flow
1. Admin creates a Head Staff user from Manage Users.
2. Set the Head Staff department to the same department as a Faculty account.
3. Login as Faculty and request a classroom.
4. Confirm the request shows `PENDING_APPROVAL` / pending in My Bookings.
5. Login as the matching Head Staff.
6. Open Approval Requests.
7. Approve or reject.
8. Login as the Faculty account and open Notifications / My Bookings.
9. Verify the booking status and notification.

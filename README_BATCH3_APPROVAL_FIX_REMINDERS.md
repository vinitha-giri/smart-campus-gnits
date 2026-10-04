# GNITS Smart Campus - Batch 3

## Included
- Faculty booking no longer creates a fake REJECTED booking when department/Head Staff setup is missing. The API returns a clear Admin-contact message and does not create the booking.
- Department matching is normalized for common names such as CSE / Computer Science and Engineering.
- Pending approval requests are visible to the correct Head Staff department.
- If multiple Head Staff accounts exist in the same department, all are notified.
- Head Staff approval screen auto-refreshes every 20 seconds.
- Notifications screen auto-refreshes every 20 seconds.
- Backend automatically sends a persistent in-app reminder every 30 minutes while a booking remains PENDING_APPROVAL.
- Reminder notifications also use the existing realtime channel when the Head Staff app is open.

## Reminder timing
The backend checks every 5 minutes. A reminder is sent after 30 minutes of pending time and then at most once every 30 minutes.

## Important
This batch implements reliable server-side/in-app reminders. Actual Android lock-screen push notifications through Firebase Cloud Messaging should be added in the next mobile-release batch after the Android Firebase configuration is confirmed, so existing Android/web functionality is not disturbed.

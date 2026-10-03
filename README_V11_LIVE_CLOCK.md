# V11 Live Clock / Occupancy UI Fix

Based on the V10 DB-driven Smart Campus project.

Changes in `frontend/smart_campus_app/lib/occupancy_screen.dart`:
- Live occupancy day now starts from Asia/Kolkata (UTC+05:30) rather than the browser timezone.
- Sunday is represented correctly instead of falling back to Monday.
- The LIVE NOW day/time display is synchronized from the backend's `checkedDay` and `checkedTime` on every successful live-status response.
- Live status continues to use the existing non-overlapping request protection.
- Capacity remains database-driven; no room capacity values were hardcoded in the Flutter screen.

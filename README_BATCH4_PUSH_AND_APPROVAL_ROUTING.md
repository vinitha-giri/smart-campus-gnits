# GNITS Smart Campus — Batch 4

This batch keeps existing UI/features and adds:

1. Persistent approval routing: a faculty booking stores its approval department, so a pending request cannot disappear if a faculty profile changes later.
2. Existing pending bookings are backfilled by the SQL migration.
3. FCM push notification infrastructure for Android. In-app notifications continue to work without FCM.
4. Secure device-token registration using a login session token.
5. Push notifications for booking request, approval, rejection and approval reminders.
6. Android notification permission.

## Database
Run `database/batch4_push_and_routing.sql` once on the same MySQL database used by Spring Boot.

## Flutter
After extracting: `flutter pub get`. Web continues to work without Firebase initialization.

For Android push, configure the Firebase Android app before building the APK/AAB. The official FlutterFire workflow is:

`dart pub global activate flutterfire_cli`

`flutterfire configure`

Select the existing `gnits-smart-campus` Firebase project and Android platform. Register the Android application with this project's application id (`com.example.smart_campus_app`) or change the application id consistently before configuration.

## Backend FCM
Create a Firebase service account for the same Firebase project and store its JSON as a base64 string in the Render environment variable:

`FIREBASE_SERVICE_ACCOUNT_JSON_B64`

Do NOT commit the service-account JSON or private key to GitHub.

The backend uses Firebase Admin Java SDK 9.11.0. If the environment variable is absent, the app still runs and keeps the existing database/in-app notification workflow.

## Test order
1. Faculty CSE creates a booking.
2. It must be PENDING_APPROVAL and appear for CSE Head Staff.
3. Head Staff approves. Faculty sees CONFIRMED and an in-app notification.
4. Configure Firebase Android + backend service account.
5. Build on a real Android phone and verify push notifications while the app is backgrounded.

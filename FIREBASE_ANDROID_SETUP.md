# Firebase Android push setup (one-time)

The source already contains the push-notification code. Before making an Android APK/AAB, connect this Flutter app to the existing Firebase project `gnits-smart-campus`.

1. Open PowerShell in `frontend\smart_campus_app`.
2. Install FlutterFire CLI if needed:
   `dart pub global activate flutterfire_cli`
3. Run:
   `flutterfire configure`
4. Select the existing Firebase project `gnits-smart-campus`.
5. Select Android (and Web only if you also want Firebase web services later).
6. Register/select the Android application id `com.example.smart_campus_app`.
7. Let FlutterFire add the Android Firebase configuration. The official Firebase docs recommend this workflow and note that the generated Firebase config contains non-secret project identifiers. 
8. Run `flutter pub get` and then `flutter run` on a physical Android phone.

Backend push setup:

1. In Firebase Console, create/download a service-account JSON for the project.
2. Do NOT put that JSON in GitHub or inside the Flutter project.
3. Convert the JSON to one-line base64 and set Render environment variable:
   `FIREBASE_SERVICE_ACCOUNT_JSON_B64`
4. Restart/deploy the Render backend.

If the backend environment variable is missing, the app still works with its existing database/realtime notifications; actual phone push is simply disabled.

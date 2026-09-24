# Smart Campus V13 — Real-Time / Production-Ready Setup

This version preserves the existing REST APIs and adds a lightweight WebSocket event channel.

## 1. Local development

### Backend
From `backend/smartcampusbackend`:

```powershell
mvn spring-boot:run
```

The API remains at `http://localhost:8080`.

### Flutter
From `frontend/smart_campus_app`:

```powershell
flutter pub get
flutter run -d chrome
```

For a deployed API, build with:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-BACKEND-DOMAIN
```

The frontend automatically converts an HTTPS API URL to a secure `wss://` WebSocket URL.

## 2. What V13 adds

- Shared WebSocket endpoint: `/ws/updates`
- Events after booking create/cancel
- Events after room create/update/delete
- Events after timetable upload/delete
- Dashboard LIVE/CONNECTING indicator
- Automatic reconnect on connection loss
- Existing room and occupancy screens continue their automatic polling, so the system remains functional even if WebSockets are temporarily unavailable.
- `/api/health` endpoint for deployment health checks.

## 3. Cloud architecture

Users -> Flutter Web -> HTTPS Spring Boot API -> MySQL
                         |
                         +-> WSS `/ws/updates`

All users use the same backend and database, so a booking made by one user can be reflected for other users.

## 4. Important production security steps

Before public college deployment:
- Replace the demo/local credentials with database-backed authentication.
- Use HTTPS/WSS.
- Store database credentials in environment variables/secrets, never in source control.
- Restrict CORS to the deployed frontend origin instead of `*`.
- Add role-based authorization on the backend, not only in the Flutter UI.
- Add database backups and monitoring.

## 5. Docker backend + MySQL

From `backend/smartcampusbackend`:

```powershell
mvn clean package -DskipTests

docker compose up --build -d
```

The compose file is intended for a controlled deployment/test environment. Change all default passwords before using it publicly.

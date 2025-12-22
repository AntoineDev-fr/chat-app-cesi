# Chat App CESI

Full stack chat app for the CESI project: PHP REST API + Docker and a Flutter mobile client.

## Stack
- PHP 8.2 (API REST) + Apache
- MySQL 8
- Docker / Docker Compose
- Flutter mobile client (polling, swipe delete, location + vibration)

## Quick start (API + DB)
1) `docker compose up -d`
2) API runs on `http://localhost:8080`
3) DB credentials (also in `docker-compose.yml`):
   - host `db` (from container) or `localhost:3306` (from host)
   - database `chatdb`, user `chatuser`, pass `chatpass`
4) Health check: `curl http://localhost:8080/health`

## API endpoints
- `POST /auth/login` `{username}`: login or creates the account, returns `{user, token}`.
- `GET /me`: current user info (requires bearer token).
- `GET /users`: list all other users.
- `GET /messages?with={id}&since={id}&limit=50`: history + incremental poll.
- `POST /messages` `{receiver_id, content}`: send a message.
- `DELETE /messages/{id}`: delete one of your messages (bonus swipe).

## Flutter mobile app
- Path: `mobile/`
- Requires Flutter SDK (3.10+ recommended).
- Run examples:
  - `flutter run -d emulator-5554` (Android emulator)
- Features:
  - Login (username only), user list, history, polling every 5s, send.
  - Swipe left on your own messages to delete (uses API DELETE).
  - Uses device: location (Geolocator) + vibration on new messages.

## Notes
- Tokens are stored server side (hashed) with 7-day expiry.
- Messages length limited to 2000 characters; SQL prepared statements everywhere.
- Emulator base URL usually `http://10.0.2.2:8080` (configurable in-app or via `--dart-define=API_BASE_URL=...`).
- To reset the database: `docker compose down -v` then `docker compose up -d`.

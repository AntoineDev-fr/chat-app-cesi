# Chat App CESI

Full stack chat app for the CESI project: PHP REST API + Docker, a lightweight web frontend, and a Flutter mobile client.

## Stack
- PHP 8.2 (API REST) + Apache
- MySQL 8
- Docker / Docker Compose
- Web frontend: vanilla HTML/CSS/JS
- Flutter mobile client (polling, swipe delete, location + vibration)

## Quick start (API + DB)
1) `docker compose up -d`
2) API runs on `http://localhost:8080`
3) DB credentials (also in `docker-compose.yml`):
   - host `db` (from container) or `localhost:3306` (from host)
   - database `chatdb`, user `chatuser`, pass `chatpass`
4) Health check: `curl http://localhost:8080/health`

## API endpoints
- `POST /auth` `{username, password}`: login or creates the account, returns token.
- `GET /me`: current user info (requires bearer token).
- `GET /users`: list all other users.
- `GET /messages/history?with={id}&limit=50`: latest history with a user.
- `GET /messages/new?with={id}&since_id={id}`: incremental poll.
- `POST /messages/send` `{to, content}`: send a message.
- `DELETE /messages/delete?id={id}`: delete one of your messages (bonus swipe).

## Web frontend (desktop demo)
- Path: `frontend/index.html`
- Quick run: `cd frontend && python -m http.server 4173` then open `http://localhost:4173`
- Enter API URL (default `http://localhost:8080`), username/password, then chat:
  - Lists users, select a contact, shows history, polls every 2s, send messages, delete yours.

## Flutter mobile app
- Path: `mobile/`
- Requires Flutter SDK (3.10+ recommended).
- One-time setup to generate platform folders if missing:
  ```
  cd mobile
  flutter create . --platforms android,ios,web
  flutter pub get
  ```
- Run examples:
  - `flutter run -d chrome` (web)
  - `flutter run -d emulator-5554` (Android emulator)
- Features:
  - Login/register, user list, history, polling every 2s, send.
  - Swipe left on your own messages to delete (uses API DELETE).
  - Uses device: location (Geolocator) + vibration on new messages.

## Notes
- Tokens are stored server side (hashed) with 7-day expiry. Passwords are Bcrypt hashed.
- Messages length limited to 2000 characters; SQL prepared statements everywhere.
- To reset the database: `docker compose down -v` then `docker compose up -d`.

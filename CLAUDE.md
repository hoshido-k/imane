# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**imane（イマネ）** is a location-based automatic notification app that sends updates to loved ones when you arrive, stay, or leave a destination. The name comes from the Japanese phrase "今ね" (imane), meaning "right now" or "just now."

### Core Features
- **Location Schedules**: Set destinations in advance with time windows
- **Auto-Notifications**: Automatic notifications on arrival (50m radius), after staying (60 min), and on departure
- **Friend Management**: Select who receives notifications from your friend list
- **Favorite Locations**: Save frequently visited places for quick reuse
- **Privacy-Focused**: 24-hour automatic data deletion, background location tracking

### Key Differentiators
- ❌ **No chat functionality** - Notifications only, sent via FCM (and LINE in Phase 2)
- 🔒 **Privacy-first**: All location data auto-deletes after 24 hours
- 📱 **iOS-only for MVP** (Android in Phase 2)
- 🎯 **Notification-centric**: "今ね、" message format for natural communication

## Project Structure

```
backend/
├── app/
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Environment configuration
│   ├── core/                # Core utilities (Firebase initialization)
│   ├── api/v1/              # API endpoint routers
│   │   ├── auth.py          # Authentication endpoints
│   │   ├── users.py         # User management
│   │   ├── friends.py       # Friend relationships
│   │   ├── notifications.py # Push notifications
│   │   ├── schedules.py     # Location schedules (NEW)
│   │   ├── favorites.py     # Favorite locations (NEW)
│   │   └── location.py      # Location tracking (NEW)
│   ├── models/              # Data models
│   ├── schemas/             # Pydantic request/response schemas
│   ├── services/            # Business logic layer
│   │   ├── geofencing.py    # Geofence detection (NEW)
│   │   └── auto_notification.py # Auto-notification triggers (NEW)
│   └── utils/               # Helper functions
└── tests/                   # Unit and integration tests

mobile/                      # Flutter frontend (iOS)
└── (Flutter project structure from poplink)
```

**Key architectural decisions:**
- All API routes are versioned under `/api/v1/`
- Firebase is used for authentication, Firestore for database, and FCM for notifications
- JWT tokens are used for session management
- Location data is stored with TTL (24 hours auto-delete)
- Background location tracking every 10 minutes
- Geofencing radius fixed at 50 meters

## Development Commands

### Backend (FastAPI)
```bash
cd backend

# Install dependencies with uv
uv sync

# Run development server (auto-reload enabled)
uv run uvicorn app.main:app --reload

# Run on specific host/port
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Run tests
uv run pytest

# Lint and format
uv run ruff check .
uv run ruff format .
```

### Frontend (Flutter)
```bash
cd mobile

# Get dependencies
flutter pub get

# Run on iOS simulator
flutter run

# Build for iOS
flutter build ios
```

## Key Configuration Files

### Backend (.env required)
```
APP_NAME=imane API
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CREDENTIALS_PATH=/path/to/serviceAccountKey.json
SECRET_KEY=your-jwt-secret
ENCRYPTION_KEY=your-encryption-key
DEBUG=False

# Location settings
GEOFENCE_RADIUS_METERS=50
LOCATION_UPDATE_INTERVAL_MINUTES=10
DATA_RETENTION_HOURS=24

# Notification settings
NOTIFICATION_STAY_DURATION_MINUTES=60
```

### Important Settings (app/config.py)
- `SECRET_KEY` - JWT token signing key
- `ACCESS_TOKEN_EXPIRE_MINUTES=30` - JWT token expiration
- `ENCRYPTION_KEY` - For encrypting sensitive data
- `GEOFENCE_RADIUS_METERS=50` - Arrival detection radius
- `NOTIFICATION_STAY_DURATION_MINUTES=60` - When to send stay notification

## Development Environment

### Local Development Setup
This project is designed for local development with the following prerequisites:

**Required Tools:**
- **Python 3.11+**: Backend runtime
- **uv**: Python package manager (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- **Flutter 3.x**: iOS app development
- **Xcode**: iOS simulator and building

**Environment Setup:**
1. Set up Firebase credentials (see backend/.env.example)
2. Install backend dependencies:
   ```bash
   cd backend && uv sync
   ```
3. Install frontend dependencies:
   ```bash
   cd mobile && flutter pub get
   ```

**Running the Development Server:**
```bash
# Backend
cd backend && uv run uvicorn app.main:app --reload

# Frontend
cd mobile && flutter run
```

### Formatters & Linters
- **Python**: Ruff (configured in `pyproject.toml` - 100 char line length)
- **Flutter**: dart format
- **VS Code**: Configure editor settings for auto-formatting on save

## Firebase Integration

The app relies on Firebase services:
- **Authentication**: User sign-up, login, token verification
- **Firestore**: All data storage (users, schedules, favorites, location history, notifications)
- **Cloud Messaging**: Push notifications (FCM)
- **Cloud Functions**: Scheduled data deletion (24-hour TTL)

Firebase is initialized in `app/core/firebase.py` and must be configured with a service account JSON file.

## Testing

### Backend Tests
```bash
cd backend
uv run pytest                    # Run all tests
uv run pytest tests/test_auth.py # Run specific test file
uv run pytest -v                 # Verbose output
```

## Common Development Workflows

### Git Branching Strategy
When working on new features or fixes:
1. Always create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Work on your feature branch
3. When ready, create a PR to merge back into main

**Branch naming conventions:**
- `feature/` - New features (e.g., `feature/geofencing-logic`)
- `fix/` - Bug fixes (e.g., `fix/notification-timing`)
- `refactor/` - Code refactoring (e.g., `refactor/location-service`)
- `docs/` - Documentation updates (e.g., `docs/api-readme`)

### Adding a New API Endpoint
1. Create router in `backend/app/api/v1/new_feature.py`
2. Define Pydantic schemas in `backend/app/schemas/new_feature.py`
3. Implement business logic in `backend/app/services/new_feature.py`
4. Register router in `backend/app/main.py`:
   ```python
   from app.api.v1 import new_feature
   app.include_router(new_feature.router, prefix="/api/v1/new_feature", tags=["New Feature"])
   ```
5. Add tests in `backend/tests/test_new_feature.py`

## Security Considerations

- All passwords must be hashed before storage
- JWT tokens expire after 30 minutes (configurable in `config.py`)
- Location data is encrypted using `ENCRYPTION_KEY`
- CORS is currently set to `*` for development - **must restrict in production**
- Never log user credentials, tokens, or precise location data
- Firebase security rules should be configured properly
- iOS location permission: "Always Allow" required for background tracking

### Privacy & Data Retention
- **Location history**: Auto-deleted after 24 hours
- **Notification history**: Auto-deleted after 24 hours
- **Schedules**: Auto-deleted 24 hours after end_time
- **Favorite locations**: Persist until user deletion
- **User data**: Deleted only on explicit account deletion

## API Endpoints Reference

### Authentication (`/api/v1/auth`) - From poplink
- `POST /signup` - Register new user
- `POST /login` - Login with email/password
- `POST /refresh` - Refresh JWT token
- `POST /logout` - Logout user

### Users (`/api/v1/users`) - From poplink
- `GET /me` - Get current user profile
- `PUT /me` - Update user profile
- `GET /{user_id}` - Get user by ID
- `DELETE /me` - Delete account

### Friends (`/api/v1/friends`) - From poplink
- `POST /request` - Send friend request
- `POST /accept` - Accept friend request
- `POST /reject` - Reject friend request
- `GET /list` - List all friends
- `DELETE /{friend_id}` - Remove friend

### Schedules (`/api/v1/schedules`) - NEW
- `POST /` - Create location schedule
- `GET /` - List all active schedules
- `GET /{id}` - Get schedule details
- `PUT /{id}` - Update schedule
- `DELETE /{id}` - Delete schedule (Phase 2)

### Favorites (`/api/v1/favorites`) - NEW
- `POST /` - Add favorite location
- `GET /` - List favorite locations
- `DELETE /{id}` - Remove favorite

### Location (`/api/v1/location`) - NEW
- `POST /update` - Update current location (called every 10 min by app)
- `GET /status` - Get current tracking status for active schedules

### Notifications (`/api/v1/notifications`)
- `POST /register` - Register FCM token
- `GET /history` - Get notification history (24 hours)

## Data Models (Firestore)

### LocationSchedule
```python
{
  "id": str,
  "user_id": str,
  "destination_name": str,
  "destination_address": str,
  "destination_coords": {"lat": float, "lng": float},
  "geofence_radius": int (default: 50),
  "notify_to_user_ids": List[str],
  "start_time": datetime,
  "end_time": datetime,
  "recurrence": Optional[str],  # "daily", "weekdays", "weekends"
  "notify_on_arrival": bool,
  "notify_after_minutes": int (default: 60),
  "notify_on_departure": bool,
  "status": str,  # "active", "arrived", "completed", "expired"
  "arrived_at": Optional[datetime],
  "departed_at": Optional[datetime],
  "favorite": bool
}
```

### FavoriteLocation
```python
{
  "id": str,
  "user_id": str,
  "name": str,
  "address": str,
  "coords": {"lat": float, "lng": float}
}
```

### LocationHistory
```python
{
  "id": str,
  "user_id": str,
  "schedule_id": str,
  "coords": {"lat": float, "lng": float},
  "recorded_at": datetime,
  "auto_delete_at": datetime  # 24 hours later
}
```

### NotificationHistory
```python
{
  "id": str,
  "from_user_id": str,
  "to_user_id": str,
  "schedule_id": str,
  "type": str,  # "arrival", "stay", "departure"
  "message": str,  # "今ね、{name}さんが{place}へ到着したよ"
  "map_link": str,
  "sent_at": datetime,
  "auto_delete_at": datetime
}
```

## Notification Message Format

All notifications follow the "今ね、" (imane) format:

### Arrival
```
今ね、{ユーザー名}さんが{目的地名}へ到着したよ
到着時刻: {HH:MM}
ここにいるよ → [地図リンク]
```

### Stay (after 60 minutes)
```
今ね、{ユーザー名}さんは{目的地名}に{X時間Y分}滞在しているよ
ここにいるよ → [地図リンク]
```

### Departure
```
今ね、{ユーザー名}さんが{目的地名}から出発したよ
出発時刻: {HH:MM}
```

## Port Reference
- **8000**: FastAPI backend API

## Implementation Phases

### Phase 1: MVP (Current)
- ✅ Authentication & user management (from poplink)
- ✅ Friend management (from poplink)
- 🆕 Location schedule CRUD
- 🆕 Favorite locations
- 🆕 Background location tracking (10 min intervals)
- 🆕 Geofencing logic (50m radius detection)
- 🆕 Auto-notification triggers (arrival, stay, departure)
- 🆕 FCM push notifications
- 🆕 24-hour data auto-deletion

### Phase 2: Enhancements
- Schedule cancellation/pause
- Notification group management
- LINE Messaging API integration
- Statistics dashboard

### Phase 3: Platform Expansion
- Android support
- Apple Watch companion app
- PWA (optional)

## Notes for Claude Code

When working on imane:

1. **Remember the core concept**: "今ね、" automatic notifications - no chat, just timely updates
2. **Privacy is paramount**: Always implement 24-hour TTL for location data
3. **From poplink template**: Auth, users, friends, notifications are reused. Messages functionality was deleted.
4. **New functionality**: Schedules, favorites, location tracking, geofencing, auto-notifications
5. **iOS-first**: Focus on iOS Background Location APIs, not Android (yet)
6. **Notification format**: Always use "今ね、" prefix and natural Japanese phrasing

### Example Development Scenario
```
User: "Add a feature to allow users to set recurring schedules"

Claude: "I'll add recurring schedule functionality. Looking at the LocationSchedule model,
there's already a 'recurrence' field that supports 'daily', 'weekdays', 'weekends'.

Let me implement:
1. Update schedule creation endpoint to validate recurrence rules
2. Add a Cloud Function to auto-create next occurrence when current schedule expires
3. Add UI in Flutter to select recurrence pattern
4. Update geofencing logic to handle multiple active schedules

The existing geofencing service in backend/app/services/geofencing.py can handle
multiple simultaneous schedules, so we just need to ensure proper filtering."
```

### Common Pitfalls
- Don't add chat/messaging features - this was intentionally removed
- Don't forget 24-hour TTL on location data
- Don't make location updates too frequent (battery drain)
- Don't send duplicate notifications (check NotificationHistory)
- Always validate geofence distance with GPS accuracy margin

## Changelog from poplink

### Removed
- ❌ `backend/app/api/v1/messages.py`
- ❌ `backend/app/schemas/message.py`
- ❌ `backend/app/services/messages.py`
- ❌ All messaging/chat functionality

### Added
- 🆕 `backend/app/api/v1/schedules.py` - Location schedule management
- 🆕 `backend/app/api/v1/favorites.py` - Favorite locations
- 🆕 `backend/app/api/v1/location.py` - Location tracking
- 🆕 `backend/app/services/geofencing.py` - Geofence detection
- 🆕 `backend/app/services/auto_notification.py` - Notification triggers
- 🆕 Location-related schemas and models

### Modified
- 📝 `backend/app/main.py` - Updated app name, removed messages router
- 📝 `backend/.env.example` - Added location and notification settings
- 📝 All documentation (README, CLAUDE.md) - imane-specific content

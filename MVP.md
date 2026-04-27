# Golf Dispersion App — MVP Specification

## Purpose

This document is the single source of truth for building the MVP of a golf dispersion app for iOS. An AI coding agent (or human developer) should be able to read this document top-to-bottom and build the entire application stage by stage without needing to ask clarifying questions.

The app overlays personalized shot dispersion ellipses onto satellite course imagery so golfers can make smarter aiming decisions during a live round. The core value proposition: instead of guessing where your shot will land, you see a statistical reality of your tendencies with each club and shot shape, adjusted for current wind conditions.

A direct competitor called **Shot Pattern** exists. Our differentiators are: real-time wind-adjusted ellipse deformation, per-shot-shape dispersion tracking (fade/draw/straight per club), and a free pricing model.

---

## Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| Frontend | SwiftUI (iOS only) | Native iOS app. No Android. No React Native. |
| Maps | MapKit with satellite imagery | Apple's native mapping framework. Satellite/hybrid view for course visualization. |
| Backend | FastAPI (Python) | REST API. Handles auth token verification, data sync, wind data proxying. |
| Auth | Firebase Authentication | Email/password and Apple Sign-In. Firebase SDK on iOS, token verification on backend. |
| Database (dev) | MySQL | Local MySQL instance for development. |
| Database (prod) | Azure Database for MySQL | Managed MySQL on Azure for production. |
| Wind Data | Open-Meteo API | Free tier. No API key required. Provides hourly wind speed, direction, gusts. |
| Tooling | Claude Code, Xcode | Primary development tools. |

---

## Architecture Overview

```
┌─────────────────────────────────┐
│         iOS App (SwiftUI)       │
│  ┌───────────┐ ┌──────────────┐ │
│  │  MapKit   │ │  Local Cache │ │
│  │ Satellite │ │  (CoreData)  │ │
│  └───────────┘ └──────────────┘ │
└──────────┬──────────────────────┘
           │ HTTPS (Bearer token)
           ▼
┌─────────────────────────────────┐
│       FastAPI Backend           │
│  ┌──────────┐ ┌──────────────┐  │
│  │ Firebase │ │  Open-Meteo  │  │
│  │  Verify  │ │    Proxy     │  │
│  └──────────┘ └──────────────┘  │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│   MySQL (dev) / Azure (prod)    │
└─────────────────────────────────┘
```

The iOS app talks to the FastAPI backend over HTTPS. Every request carries a Firebase ID token in the Authorization header. The backend verifies this token, then reads/writes to MySQL. Wind data is fetched by the backend from Open-Meteo and returned to the client — the iOS app never calls Open-Meteo directly (this lets us cache wind responses and avoids CORS-like issues).

Local persistence on the device uses CoreData as an offline cache so the app remains usable without connectivity. CoreData syncs with the backend when the network is available.

---

## Data Models

### User
| Field | Type | Notes |
|---|---|---|
| id | UUID | Primary key. Generated server-side. |
| firebase_uid | VARCHAR(128) | Firebase Authentication UID. Unique. |
| email | VARCHAR(255) | From Firebase. |
| display_name | VARCHAR(100) | Optional. |
| created_at | DATETIME | Auto-set on creation. |
| updated_at | DATETIME | Auto-updated. |

### Club
| Field | Type | Notes |
|---|---|---|
| id | UUID | Primary key. |
| user_id | UUID | FK → User. |
| name | VARCHAR(50) | E.g. "Driver", "7 Iron", "56° Wedge". |
| club_type | ENUM | DRIVER, WOOD, HYBRID, IRON, WEDGE, PUTTER. |
| loft_degrees | FLOAT | Optional. User can enter if they want. |
| display_order | INT | User-controlled ordering in the bag. |
| is_active | BOOLEAN | Soft-delete. Users can deactivate clubs without losing shot data. |
| created_at | DATETIME | |
| updated_at | DATETIME | |

A user's bag contains up to 14 clubs (USGA rule). The app should warn but not hard-block if they exceed 14 — some users track clubs they rotate in and out.

### Shot
| Field | Type | Notes |
|---|---|---|
| id | UUID | Primary key. |
| club_id | UUID | FK → Club. |
| user_id | UUID | FK → User. Denormalized for query speed. |
| shot_shape | ENUM | FADE, DRAW, STRAIGHT. |
| carry_yards | FLOAT | How far the ball carried in the air. |
| offline_yards | FLOAT | Lateral deviation from the aim line. Positive = right, negative = left. |
| total_yards | FLOAT | Optional. Carry + roll. Not used in dispersion calc but useful for the user. |
| notes | TEXT | Optional free-text. |
| logged_at | DATETIME | When the shot was hit (not when it was entered). |
| created_at | DATETIME | |

### CourseBookmark (future consideration, not MVP-critical)
| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| user_id | UUID | FK → User. |
| course_name | VARCHAR(200) | |
| latitude | DOUBLE | Center of the course. |
| longitude | DOUBLE | |
| created_at | DATETIME | |

---

## Dispersion Model — The Math

This is the core intellectual property of the app. Every calculation described here must be implemented exactly.

### Inputs
For a given (club, shot_shape) pair, collect all logged shots. Each shot provides two values:
- **carry_yards**: distance along the aim line
- **offline_yards**: lateral deviation from the aim line (positive = right, negative = left)

### Minimum Data Threshold
An ellipse requires **at least 4 shots** for the given (club, shot_shape) combination. Below 4 shots, do not render an ellipse — instead show a text indicator like "3/4 shots logged" so the user knows they're close.

### Computing the Ellipse

1. **Mean carry** = arithmetic mean of all carry_yards values for this (club, shot_shape).
2. **Mean offline** = arithmetic mean of all offline_yards values.
3. **Standard deviation carry** (σ_carry) = sample standard deviation of carry_yards.
4. **Standard deviation offline** (σ_offline) = sample standard deviation of offline_yards.
5. **Covariance** between carry and offline = sample covariance.

From these, construct the 2×2 covariance matrix:
```
Σ = | σ_carry²           cov(carry, offline) |
    | cov(carry, offline) σ_offline²          |
```

6. **Eigendecomposition** of Σ gives two eigenvalues (λ₁, λ₂) and their eigenvectors. The eigenvectors define the rotation angle of the ellipse. The eigenvalues define the axis lengths.

7. **Confidence ellipse scaling**: for a 2D Gaussian, the scale factor `s` for a given confidence level `p` is:
   - `s = √(-2 × ln(1 - p))`
   - For **50% confidence**: s = √(-2 × ln(0.5)) ≈ 1.1774
   - For **90% confidence**: s = √(-2 × ln(0.1)) ≈ 2.1460

8. **Ellipse semi-axes**:
   - Semi-major = s × √λ₁ (where λ₁ is the larger eigenvalue)
   - Semi-minor = s × √λ₂

9. **Ellipse center** = (mean_carry, mean_offline), positioned along the user's aim line from their current position.

10. **Rotation angle** = atan2(eigenvector₁.y, eigenvector₁.x), where eigenvector₁ corresponds to the larger eigenvalue.

### Rendering
Two concentric ellipses are drawn:
- **Inner ellipse (50%)**: "Your shot lands here half the time." Rendered with a more opaque fill.
- **Outer ellipse (90%)**: "9 out of 10 shots land in this zone." Rendered with a less opaque fill.

Both ellipses share the same center and rotation. Only the scale factor differs.

---

## Wind Adjustment Model

Wind modifies the dispersion ellipse in three ways. All adjustments use simplified linear approximations — deliberately chosen for tractability while remaining physically grounded.

### Wind Data Source
Open-Meteo API. Fetch current wind speed (m/s), wind direction (degrees, meteorological convention: 0° = wind FROM north), and wind gusts. Convert wind speed to mph for calculations (1 m/s = 2.237 mph).

### Decomposing Wind
Given the player's aim direction (bearing in degrees from north) and wind direction:
1. Compute the angle between wind direction and aim direction.
2. **Headwind component** = wind_speed × cos(angle). Positive = headwind, negative = tailwind.
3. **Crosswind component** = wind_speed × sin(angle). Positive = wind pushing right, negative = pushing left.

### Adjustments

**Distance (carry) adjustment:**
- Headwind: reduce carry by **1% per mph** of headwind component.
- Tailwind: increase carry by **0.5% per mph** of tailwind component.
- Applied to the ellipse center's carry coordinate.

**Lateral (offline) adjustment:**
- Crosswind: shift the ellipse center laterally by **0.5% of carry distance per mph** of crosswind component.

**Ellipse deformation (width):**
- Headwind also **widens the ellipse** along the lateral axis. Multiply σ_offline by (1 + 0.02 × headwind_mph). This reflects the fact that headwind amplifies sidespin effects.
- Tailwind does NOT narrow the ellipse (asymmetric effect).

### Tournament Mode
A toggle in settings called **Tournament Mode**. When active:
- Wind data is **not fetched**.
- Wind-adjusted ellipses are **not displayed**.
- Only raw (calm conditions) ellipses are shown.
- A small badge/indicator shows that Tournament Mode is active.
- This exists for **USGA compliance** — rules prohibit using wind-assistance devices during sanctioned play.

---

## API Endpoints (FastAPI Backend)

All endpoints except `/health` require a valid Firebase ID token in the `Authorization: Bearer <token>` header.

### Auth
| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/auth/register` | Create user record after Firebase signup. Body: `{ firebase_uid, email, display_name? }` |
| GET | `/api/v1/auth/me` | Return current user profile. |

### Clubs
| Method | Path | Description |
|---|---|---|
| GET | `/api/v1/clubs` | List all clubs for the authenticated user. Ordered by display_order. |
| POST | `/api/v1/clubs` | Create a new club. Body: `{ name, club_type, loft_degrees?, display_order }` |
| PUT | `/api/v1/clubs/{club_id}` | Update a club. |
| DELETE | `/api/v1/clubs/{club_id}` | Soft-delete (set is_active = false). |
| PUT | `/api/v1/clubs/reorder` | Bulk update display_order. Body: `[{ club_id, display_order }, ...]` |

### Shots
| Method | Path | Description |
|---|---|---|
| GET | `/api/v1/clubs/{club_id}/shots` | List all shots for a club. Optional query param `?shape=FADE` to filter. |
| POST | `/api/v1/clubs/{club_id}/shots` | Log a new shot. Body: `{ shot_shape, carry_yards, offline_yards, total_yards?, notes?, logged_at }` |
| DELETE | `/api/v1/shots/{shot_id}` | Hard-delete a shot. |
| GET | `/api/v1/dispersion/{club_id}/{shot_shape}` | Return computed dispersion data (mean, covariance matrix, ellipse params). |
| GET | `/api/v1/dispersion/{club_id}` | Return dispersion for all shapes of a club. |

### Wind
| Method | Path | Description |
|---|---|---|
| GET | `/api/v1/wind?lat={lat}&lon={lon}` | Proxy to Open-Meteo. Returns current wind speed (mph), direction (degrees), gusts. Backend caches responses for 10 minutes per coordinate bucket (rounded to 2 decimal places). |

### Sync
| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/sync/push` | Bulk upload local changes. Body: `{ clubs: [...], shots: [...] }` |
| GET | `/api/v1/sync/pull?since={iso_datetime}` | Pull all changes since a given timestamp. |

### Health
| Method | Path | Description |
|---|---|---|
| GET | `/health` | No auth. Returns `{ status: "ok" }`. |

---

## Development Stages

### STAGE 1 — Satellite Map View

**Goal**: Display a full-screen satellite map that the user can pan, zoom, and interact with. This is the foundational screen of the entire app.

**Why start here**: The map is the canvas everything else gets painted onto. If the map feels wrong — laggy, ugly tiles, bad zoom — nothing else matters.

**Tasks**:
1. Create a new Xcode project. SwiftUI lifecycle. Target iOS 17+. Bundle identifier TBD (use a placeholder like `com.golfapp.dispersion`).
2. Add MapKit import. Use `Map` view with `.imagery` (satellite) map style.
3. Default the map to the user's current location using CoreLocation. Request "When In Use" location permission.
4. If location permission is denied, default to a known golf course (e.g., Augusta National: 33.5030° N, 82.0229° W — a recognizable fallback).
5. Add a floating button (bottom-right) that re-centers the map on the user's current location.
6. Implement a crosshair/pin at the center of the screen that the user can position by panning the map. This pin represents "where I am standing right now" — the origin point for dispersion overlays. The pin does NOT move with the map; the map moves under it.
7. Display the current coordinate (lat/lon) of the pin in a small, unobtrusive label. This is a debug aid during development — can be hidden later.
8. Test on a real device if possible. Satellite tile loading latency is the main concern.

**Acceptance criteria**:
- App launches to a full-screen satellite map.
- Map starts at user's GPS location (or fallback).
- User can pan and zoom smoothly.
- Center pin stays fixed on screen.
- Re-center button works.
- Location permission flow is handled gracefully (request → granted / denied).

**File structure after this stage**:
```
GolfApp/
├── GolfApp.swift                  (App entry point)
├── Views/
│   └── MapView.swift              (Main map screen)
├── ViewModels/
│   └── LocationManager.swift      (CoreLocation wrapper)
├── Info.plist                     (Location usage descriptions)
└── Assets.xcassets/
```

---

### STAGE 2 — Backend Foundation

**Goal**: Stand up the FastAPI backend with Firebase auth verification, MySQL database, and basic CRUD endpoints for users and clubs.

**Why second**: The map is visual and motivating, but we need a backend before we can persist anything. Getting auth and data storage right early prevents painful rewrites.

**Tasks**:
1. Create a `backend/` directory at the project root.
2. Set up a Python virtual environment. Python 3.11+.
3. Install dependencies: `fastapi`, `uvicorn`, `sqlalchemy`, `pymysql`, `firebase-admin`, `python-dotenv`, `pydantic`.
4. Create the FastAPI app with CORS middleware (allow all origins during dev).
5. Set up SQLAlchemy models matching the data models section above. Use UUID primary keys.
6. Create a `.env` file for config: `DATABASE_URL`, `FIREBASE_CREDENTIALS_PATH`.
7. Implement Firebase token verification middleware. Every request (except `/health`) must have a valid `Authorization: Bearer <token>` header. Decode the token with `firebase_admin.auth.verify_id_token()`. Attach the decoded user info to the request state.
8. Implement the `/health` endpoint.
9. Implement `/api/v1/auth/register` and `/api/v1/auth/me`.
10. Implement full CRUD for clubs (`/api/v1/clubs/*`).
11. Write a database migration script or use Alembic for schema management.
12. Test with `curl` or httpie. Verify that requests without a valid token return 401.

**Acceptance criteria**:
- `uvicorn` starts without errors.
- `/health` returns 200.
- Unauthenticated requests to protected endpoints return 401.
- Can create a user, create clubs, list clubs, update a club, soft-delete a club.
- Database tables are created correctly in local MySQL.

**File structure after this stage**:
```
backend/
├── main.py                        (FastAPI app, CORS, middleware)
├── .env                           (Config, gitignored)
├── .env.example                   (Template)
├── requirements.txt
├── auth/
│   └── firebase.py                (Token verification)
├── models/
│   ├── user.py
│   ├── club.py
│   └── shot.py
├── schemas/
│   ├── user.py                    (Pydantic request/response models)
│   ├── club.py
│   └── shot.py
├── routes/
│   ├── auth.py
│   ├── clubs.py
│   └── health.py
├── database.py                    (SQLAlchemy engine, session)
└── config.py                      (Settings from .env)
```

---

### STAGE 3 — Club Bag Management (iOS)

**Goal**: Build the UI for managing the user's club bag — adding, editing, reordering, and deactivating clubs. This is the first screen that touches Firebase Auth and the backend.

**Tasks**:
1. Integrate Firebase iOS SDK. Add `firebase-ios-sdk` via Swift Package Manager. Configure `GoogleService-Info.plist`.
2. Build a simple auth flow: a login/signup screen with email/password fields and an "Sign in with Apple" button. On successful auth, call `/api/v1/auth/register` to ensure the user exists in the backend.
3. Create a `NetworkManager` (or `APIClient`) singleton that attaches the Firebase ID token to every request. Handle token refresh automatically using Firebase's `getIDToken(completion:)`.
4. Build `BagView`: a list of the user's clubs, ordered by `display_order`. Each row shows club name, type, and a count of logged shots.
5. Build `AddClubView`: a form with fields for name, club_type (picker), loft_degrees (optional numeric field), and display_order.
6. Support drag-to-reorder in the club list. On drop, call `/api/v1/clubs/reorder`.
7. Swipe-to-deactivate on a club row. This calls the soft-delete endpoint. Show deactivated clubs in a collapsed "Inactive" section at the bottom, with an option to reactivate.
8. Add a tab bar at the bottom of the app with two tabs: **Map** and **Bag**. Map shows the satellite view from Stage 1. Bag shows the club list.

**Acceptance criteria**:
- User can sign up, log in, and sign out.
- User can add a club with name and type.
- Club list displays in correct order.
- User can drag to reorder clubs.
- User can swipe to deactivate/reactivate a club.
- Data persists across app restarts (backed by the API).
- Tab bar navigation works between Map and Bag.

**File structure additions**:
```
GolfApp/
├── Services/
│   ├── APIClient.swift            (HTTP client with Firebase token)
│   └── AuthService.swift          (Firebase Auth wrapper)
├── Views/
│   ├── MapView.swift
│   ├── BagView.swift              (Club list)
│   ├── AddClubView.swift          (Add/edit club form)
│   ├── LoginView.swift            (Auth screen)
│   └── ContentView.swift          (Tab bar container)
├── Models/
│   ├── Club.swift                 (Codable struct)
│   └── User.swift
└── ViewModels/
    ├── LocationManager.swift
    ├── BagViewModel.swift
    └── AuthViewModel.swift
```

---

### STAGE 4 — Shot Logging

**Goal**: Allow users to log individual shots with carry distance, offline distance, and shot shape. This is the data-entry pipeline that feeds the dispersion engine.

**Tasks**:
1. Implement backend endpoints for shots: `POST /api/v1/clubs/{club_id}/shots`, `GET /api/v1/clubs/{club_id}/shots`, `DELETE /api/v1/shots/{shot_id}`.
2. Build `LogShotView`: accessed from the Bag screen by tapping a club. Fields:
   - **Shot shape**: segmented picker (Fade / Straight / Draw).
   - **Carry distance**: numeric input in yards. Large, easy-to-tap input since this will be used on the course.
   - **Offline distance**: numeric input. Include a +/- toggle or slider for left/right. Positive = right, negative = left.
   - **Total distance**: optional numeric input.
   - **Notes**: optional text field.
   - **Date**: defaults to now, but user can backfill.
3. Build `ShotHistoryView`: list of all shots for a given club, grouped by shot shape. Each row shows carry, offline, shape, and date. Swipe-to-delete.
4. Show shot counts per shape in the club list row. E.g., "7 Iron — F:12 S:8 D:5" so the user can see at a glance which shapes have enough data.
5. Add a "quick log" affordance: from the Map tab, a floating "+" button that opens a sheet for logging a shot without navigating away from the map. Pre-selects the last-used club.

**Design note on input UX**: This app will be used on a golf course, likely in bright sunlight with one hand. Inputs must be large, high-contrast, and minimal-tap. Prefer steppers or large number pads over small text fields. The most common flow is: select club → select shape → enter carry → enter offline → save. That's 5 taps maximum for the happy path.

**Acceptance criteria**:
- Can log a shot with all required fields.
- Shot appears in history immediately.
- Can delete a shot.
- Shot counts appear on club list.
- Quick-log from map works.
- Input controls are usable in outdoor/bright conditions (large touch targets, high contrast).

---

### STAGE 5 — Dispersion Engine

**Goal**: Implement the statistical engine that computes confidence ellipses from logged shot data. This is pure math — no UI yet.

**Tasks**:
1. Implement the dispersion computation on the **backend** at `/api/v1/dispersion/{club_id}/{shot_shape}`. The response should include:
   ```json
   {
     "club_id": "uuid",
     "shot_shape": "FADE",
     "shot_count": 15,
     "mean_carry": 165.3,
     "mean_offline": 4.2,
     "covariance_matrix": [[s_cc, s_co], [s_co, s_oo]],
     "ellipse_50": {
       "semi_major": 12.4,
       "semi_minor": 5.1,
       "rotation_degrees": 8.3
     },
     "ellipse_90": {
       "semi_major": 22.6,
       "semi_minor": 9.3,
       "rotation_degrees": 8.3
     }
   }
   ```
2. If shot_count < 4, return the shot count but no ellipse data. Include a field like `"sufficient_data": false`.
3. Also implement this computation **on the iOS side** for offline use. Create a `DispersionEngine` class in Swift that takes an array of shots and returns the same ellipse parameters. Use the Accelerate framework for matrix math if helpful, but correctness matters more than performance here — we're talking about matrices of at most a few hundred values.
4. Write unit tests for the dispersion engine. Test cases:
   - Exactly 4 shots → valid ellipse.
   - 3 shots → no ellipse.
   - All shots identical → degenerate ellipse (zero variance). Handle gracefully — don't crash, show a point or a very small circle.
   - Shots with zero offline variance → ellipse collapses to a line along the carry axis. Handle this by adding a tiny epsilon to prevent division by zero.
   - Large dataset (100+ shots) → verify ellipse visually makes sense.

**Acceptance criteria**:
- Backend endpoint returns correct ellipse parameters for a given club/shape.
- iOS engine produces identical results to the backend for the same input data.
- Edge cases (< 4 shots, zero variance, degenerate covariance) are handled without crashes.
- Unit tests pass.

---

### STAGE 6 — Ellipse Overlay on Map

**Goal**: Render the dispersion ellipses on the satellite map. This is the core visual feature — the thing that makes this app worth using.

**Tasks**:
1. When the user selects a club and shot shape (via a bottom sheet or floating selector on the Map tab), compute the dispersion ellipse.
2. Convert the ellipse from yards-based coordinates to geographic coordinates:
   - The ellipse center is at (mean_carry, mean_offline) yards from the pin (the user's standing position, from Stage 1).
   - The user specifies an **aim direction** by tapping a point on the map. The bearing from the pin to the tapped point defines the aim line.
   - Mean_carry yards along the aim bearing gives the ellipse center's latitude/longitude.
   - Mean_offline yards perpendicular to the aim bearing shifts the center laterally.
   - Use the "destination point given distance and bearing" formula (Vincenty or simplified spherical) for coordinate conversion. At golf-course scales (< 300 yards), spherical approximation is fine.
3. Render the two ellipses (50% and 90%) as `MKOverlay` objects on the map. Use `MKOverlayRenderer` to draw them. Colors:
   - 50% ellipse: filled with a semi-transparent color (e.g., rgba blue, alpha 0.35).
   - 90% ellipse: filled with a more transparent version (e.g., rgba blue, alpha 0.15), with a visible border.
4. The aim line should be drawn as a thin line from the pin to the ellipse center and beyond.
5. As the user changes aim direction (by tapping a new point), the ellipse re-renders at the new position instantly.
6. Add a **club selector** UI element on the map screen — a horizontally scrollable strip of club buttons at the bottom. Tapping a club shows its ellipses. Tapping a selected club deselects it (hides ellipses).
7. Add a **shot shape selector** — three small buttons (F/S/D) that appear when a club is selected. Default to showing all shapes with different colors:
   - Fade: blue
   - Straight: green
   - Draw: orange
8. The user must always retain manual control. Never silently remove a club or shape from the display. If the user selects "show all shapes," show all three (if data exists). Let them toggle each on/off independently.

**Coordinate conversion detail**:
Given an origin point (lat₀, lon₀), a bearing θ (degrees from north), and a distance d (yards):
1. Convert d to meters: d_m = d × 0.9144
2. Convert d_m to radians of arc: δ = d_m / 6371000 (Earth's radius in meters)
3. Destination latitude: lat₁ = asin(sin(lat₀) × cos(δ) + cos(lat₀) × sin(δ) × cos(θ))
4. Destination longitude: lon₁ = lon₀ + atan2(sin(θ) × sin(δ) × cos(lat₀), cos(δ) - sin(lat₀) × sin(lat₁))

For the perpendicular offset (offline yards), use bearing θ + 90° (or θ - 90° for negative offline).

**Acceptance criteria**:
- Selecting a club shows its dispersion ellipse(s) on the satellite map.
- Tapping on the map sets the aim direction; ellipses reposition correctly.
- Two concentric ellipses (50% and 90%) are visible with distinct opacity.
- Switching clubs or shapes updates the overlay instantly.
- Ellipses are geographically accurate — zooming in/out doesn't distort them relative to the terrain.
- Multiple shapes can be shown simultaneously in different colors.

---

### STAGE 7 — Wind Integration

**Goal**: Fetch real-time wind data and deform the dispersion ellipses accordingly.

**Tasks**:
1. Implement the backend wind proxy endpoint: `GET /api/v1/wind?lat={lat}&lon={lon}`.
   - Call Open-Meteo's forecast API: `https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=wind_speed_10m,wind_direction_10m,wind_gusts_10m`
   - Convert wind_speed from m/s to mph.
   - Cache the response for 10 minutes per coordinate bucket (round lat/lon to 2 decimal places for cache key).
   - Return: `{ wind_speed_mph, wind_direction_degrees, wind_gusts_mph, fetched_at }`.
2. On the iOS side, create a `WindService` that calls this endpoint periodically (every 5 minutes while the app is in the foreground and the Map tab is active).
3. Display a **wind indicator** on the map: a small arrow showing wind direction and speed in mph. Position it in the top-right corner of the map, always visible. The arrow should rotate to show the actual wind direction.
4. Implement the wind adjustment logic in the `DispersionEngine`:
   - Accept wind data and aim direction as inputs.
   - Decompose wind into head/tail and crosswind components.
   - Adjust ellipse center (carry and offline shifts).
   - Adjust ellipse width (headwind widens σ_offline).
   - Return both the raw ellipse and the wind-adjusted ellipse.
5. On the map, show the **wind-adjusted ellipse** by default. Add a toggle to show/hide the raw (no-wind) ellipse underneath it as a ghost outline, so users can see how much the wind is affecting their dispersion.
6. Implement **Tournament Mode**:
   - Add a toggle in a Settings screen.
   - When active: wind is not fetched, wind indicator is hidden, only raw ellipses are shown.
   - Show a small "T" badge on the map to indicate Tournament Mode is active.
   - Persist this setting in UserDefaults.

**Acceptance criteria**:
- Wind data displays on the map with correct direction and speed.
- Ellipses shift and deform based on wind.
- Switching aim direction recalculates wind decomposition correctly.
- Tournament Mode disables all wind features.
- Wind data refreshes every 5 minutes without user intervention.
- App handles wind API failures gracefully (show stale data with a "last updated" timestamp, or fall back to no-wind ellipses).

---

### STAGE 8 — Offline Support & Data Sync

**Goal**: Make the app usable without an internet connection (golf courses often have poor connectivity) and sync data when back online.

**Tasks**:
1. Set up **CoreData** on the iOS side with entities mirroring the backend models (Club, Shot). Include a `sync_status` field on each entity: `synced`, `pending_push`, `pending_delete`.
2. All data writes go to CoreData first, then sync to the backend asynchronously.
3. Implement **push sync**: on app launch, on foregrounding, and periodically (every 2 minutes while active), check for `pending_push` records and POST them to `/api/v1/sync/push`.
4. Implement **pull sync**: call `/api/v1/sync/pull?since={last_sync_timestamp}` to get any changes made from other sessions.
5. Conflict resolution: **last-write-wins** based on `updated_at` timestamp. This is simple and sufficient for a single-user app.
6. The dispersion engine on iOS should compute ellipses from CoreData, not from API responses. This ensures the app works fully offline.
7. Cache the last-known wind data in UserDefaults. If the wind API is unreachable, use cached data and indicate its age on the UI.
8. Handle the case where the user logs shots offline for days, then syncs — the bulk push should handle hundreds of shots without timeout.

**Acceptance criteria**:
- User can log shots, add clubs, and view dispersion ellipses with no internet connection.
- When connectivity returns, local changes sync to the backend.
- No data is lost during offline periods.
- Dispersion calculations work identically online and offline.
- Sync status is not visible to the user in normal operation (no distracting sync indicators). Only show a warning if sync has failed for more than 1 hour.

---

### STAGE 9 — Polish & Ship

**Goal**: Make the app feel native, clean, and ready for a first release on TestFlight.

**Tasks**:
1. **Onboarding flow**: First launch shows 3-4 swipeable cards explaining what the app does, then drops the user into signup. No video, no complex animations — just clear text and a screenshot/illustration per card.
2. **Empty states**: Every list (clubs, shots, dispersion) needs a friendly empty state. E.g., the Map with no club selected shows a hint: "Tap a club below to see your dispersion."
3. **Loading states**: Skeleton screens or subtle spinners. Never a blank screen.
4. **Error handling**: Network errors show a non-blocking toast/banner, not an alert that interrupts flow.
5. **Haptics**: Light haptic feedback on key actions (logging a shot, selecting a club on the map).
6. **Dark mode**: Full dark mode support. The satellite map looks good in both modes, but the UI chrome needs to adapt.
7. **App icon and launch screen**: Clean, minimal. Avoid golf clichés (no crossed clubs, no golf balls). Consider an abstract ellipse motif.
8. **Settings screen**: Account info, Tournament Mode toggle, unit preference (yards/meters — future), sign out, app version.
9. **TestFlight build**: Set up App Store Connect, create a provisioning profile, upload a build. Invite 5-10 beta testers.
10. **Privacy**: Add a privacy policy URL (can be a simple GitHub Pages site). Required for App Store submission. Address GDPR basics — the user is EU-based.
11. **Performance audit**: Profile with Instruments. Satellite tile loading, ellipse rendering, and list scrolling should all be smooth at 60fps.

**Acceptance criteria**:
- App feels like a native iOS app, not a web wrapper.
- No crashes in normal usage flows.
- Dark mode works throughout.
- Onboarding is clear and skippable.
- TestFlight build installs and runs on a physical device.
- Privacy policy exists and is linked in App Store Connect.

---

## Non-Functional Requirements

**Performance**: Map interactions (pan, zoom) must be 60fps. Ellipse computation for a single club/shape should complete in < 50ms on an iPhone 12 or newer. Shot logging (tap to saved) should feel instant (< 200ms perceived latency).

**Security**: Firebase ID tokens expire after 1 hour. The iOS SDK refreshes them automatically. The backend must verify tokens on every request — never trust a client-provided user_id without token verification. All API communication over HTTPS.

**Data integrity**: The dispersion engine must produce identical results on iOS and backend for the same input data. Write shared test vectors (JSON files with input shots and expected ellipse output) and validate both implementations against them.

**Privacy / GDPR**: The user is EU-based. At minimum for MVP: provide a way to export all personal data (JSON dump), provide a way to delete the account and all associated data, and include a privacy policy explaining what data is collected and why. Full GDPR compliance (consent management, DPO, etc.) is post-MVP but the architecture should not make it harder.

**Accessibility**: VoiceOver support for all interactive elements. Dynamic type for text. This is not just nice-to-have — App Store reviewers check for it.

---

## What Is NOT in the MVP

These features are explicitly out of scope. Do not build them. They are documented here so the agent knows not to scope-creep.

- Android support
- Social features (sharing, leaderboards, friends)
- GPS-based automatic shot tracking (Arccos-style)
- Course database or course search
- Hole-by-hole scoring / scorecard
- Club recommendations or AI insights
- Paid tier / subscriptions / in-app purchases
- Push notifications
- Apple Watch companion
- Landscape orientation support
- iPad-specific layouts
- Shot shape auto-detection
- Integration with launch monitors (Trackman, Garmin, etc.)

---

## Naming

The app name is undecided. The working name is **"dispersa"** but the .com domain is taken. Short, made-up names are being explored. For now, use the placeholder name **"GolfApp"** in all code, bundle identifiers, and UI text. The name will be swapped in before the first public release.

---

## Key Principles (for the agent)

1. **Human-readable code over clever code.** Prefer clarity. No code golf. No premature optimization.
2. **No comments in code.** The code should be self-documenting through clear naming. If something needs a comment, rename the thing instead.
3. **Users must always retain manual control.** Never silently remove options, auto-dismiss selections, or make choices for the user.
4. **The app must feel native.** Use standard iOS patterns (tab bars, sheets, navigation stacks). Don't reinvent UIKit/SwiftUI conventions.
5. **Stage-by-stage.** Complete one stage fully before starting the next. Each stage should result in a working, testable app — never a half-broken intermediate state.
6. **Explain every action.** When building, describe what you're doing and why before writing code. If you need to make an architectural decision not covered by this document, state the options, pick one, and explain your reasoning.
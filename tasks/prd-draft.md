# PRD: NutritionAI Web App (Firebase Hosted)

## Introduction
Create a mobile-first web app that mirrors the existing NutritionAI iOS app's core functionality and visual style, hosted on Firebase (project: nutritionai2026). The web app will reuse the existing backend API (Fastify + Firestore/Postgres abstraction) for authentication, analysis, stats, and history, while providing a responsive UI that mimics the iOS experience.

## Assumptions and Defaults (Clarifying Questions Answered)
- Scope: New additive feature (a new web app) with no required changes to existing iOS app.
- Areas touched: New web frontend only; backend changes limited to configuration (CORS allowlist and env updates) if needed.
- Backward compatibility: Fully backward compatible; existing APIs remain unchanged.
- Patterns: Follow existing backend API patterns; mirror iOS UI patterns and color system from `NutritionAI/Sources/NutritionAI/Theme/AppTheme.swift`.
- Testing: Add tests for new web app code only; keep existing backend and iOS tests passing.

## Goals
- Deliver a web app with feature parity for core iOS flows: auth, home stats, camera analyze, history, settings.
- Provide a mobile-first, touch-friendly UI that closely mimics the iOS app visuals and IA.
- Host the web app on Firebase Hosting under the nutritionai2026 project.
- Reuse existing backend endpoints without breaking changes.

## Integration Points

### Existing Components to Modify
- `backend/src/server.ts` - Confirm/adjust CORS policy to allow the Firebase Hosting domain.
- `backend/README.md` and `backend/FIREBASE_DEPLOYMENT.md` - Document web app base URL and deployment notes (if needed).

### Existing Components to Reuse
- Backend endpoints:
  - `backend/src/routes/auth.ts` (POST `/api/auth/register`, `/api/auth/login`)
  - `backend/src/routes/user.ts` (GET `/api/user/stats`)
  - `backend/src/routes/analyze.ts` (POST `/api/analyze`)
  - `backend/src/routes/meals.ts` (GET `/api/meals`, `/api/meals/:id`)
- Backend services:
  - `backend/src/services/database.ts` (Firestore/Postgres abstraction)
  - `backend/src/services/firebase.ts` (Firebase initialization for Firestore)
- iOS design references:
  - `NutritionAI/Sources/NutritionAI/Theme/AppTheme.swift` (colors, gradients, glassmorphism)
  - `NutritionAI/Sources/NutritionAI/Views/HomeView.swift` (layout, stats, quick capture)
  - `NutritionAI/Sources/NutritionAI/Views/HistoryView.swift` (list + details)
  - `NutritionAI/Sources/NutritionAI/Views/LoginView.swift` (login layout)
  - `NutritionAI/Sources/NutritionAI/Views/SettingsView.swift` (settings sections)

### New Files to Create
- `web/` (new frontend app root)
  - `web/package.json` - React + Vite + TypeScript app
  - `web/src/App.tsx` - App shell and routing
  - `web/src/routes/*` - Home, Camera, History, Settings, Login/Register
  - `web/src/components/*` - shared UI (cards, tiles, headers)
  - `web/src/services/api.ts` - API client for backend endpoints
  - `web/src/services/auth.ts` - auth state + token storage
  - `web/src/styles/*` - Tailwind or CSS variables matching iOS theme
  - `web/index.html` - mobile viewport meta and app title
- Firebase Hosting config at repo root or `web/`:
  - `firebase.json`
  - `.firebaserc`

### Database Changes
- None. Web app uses existing API and database schema.

## Compatibility

### Backward Compatibility
- No breaking changes to existing backend endpoints.
- iOS app remains unaffected.

### Migration Requirements
- None.

### Deprecations
- None.

## User Stories

### US-001: Scaffold the web app
**Description:** As a developer, I want a new web frontend that builds locally and is ready for Firebase Hosting.

**Acceptance Criteria:**
- [ ] Create a React + Vite + TypeScript app under `web/`
- [ ] Mobile-first layout with routing (Home, Camera, History, Settings, Auth)
- [ ] Environment config supports `VITE_API_BASE_URL`
- [ ] `npm run build` succeeds for the web app
- [ ] Typecheck passes

**Integration Notes:**
- Adds: `web/`
- Uses: Firebase Hosting config files

---

### US-002: API client and auth state
**Description:** As a user, I want to sign in and have my session persist so I can access my data.

**Acceptance Criteria:**
- [ ] API client supports `/api/auth/register`, `/api/auth/login`, `/api/user/stats`, `/api/analyze`, `/api/meals`
- [ ] JWT token stored securely in browser storage and attached to requests
- [ ] 401 responses clear session and return user to login
- [ ] Error messages mirror backend error responses
- [ ] Typecheck passes

**Integration Notes:**
- Uses: existing backend auth endpoints
- Pattern: follow API error handling patterns from iOS `APIService.swift`

---

### US-003: Login, registration, and guest mode
**Description:** As a new user, I want to register or try the app as a guest from a mobile-friendly UI.

**Acceptance Criteria:**
- [ ] Login and Register screens mirror iOS layout (gradient header, card form)
- [ ] Guest mode available with clear disclaimer (local-only data)
- [ ] Validation errors displayed inline
- [ ] Works on small screens (<= 375px wide)
- [ ] Verify in browser (mobile viewport)

**Integration Notes:**
- References: `NutritionAI/Sources/NutritionAI/Views/LoginView.swift`
- Reuses: iOS color palette and gradient style

---

### US-004: Home dashboard with stats and quick capture
**Description:** As a logged-in user, I want a home dashboard showing my stats and quick capture actions.

**Acceptance Criteria:**
- [ ] Fetch stats from `/api/user/stats` and display Today/Week/All Time cards
- [ ] Quick capture button routes to Camera
- [ ] Guest users see a guest-mode card and no stats fetch
- [ ] Pull-to-refresh or refresh button supported on mobile
- [ ] Verify in browser (mobile viewport)

**Integration Notes:**
- References: `NutritionAI/Sources/NutritionAI/Views/HomeView.swift`
- Uses: stats card patterns from `StatsCard.swift`

---

### US-005: Camera capture and analyze flow
**Description:** As a user, I want to capture or upload a meal photo and get nutrition results.

**Acceptance Criteria:**
- [ ] Support device camera via `getUserMedia` on mobile; fallback to file upload
- [ ] Show preview with retake/confirm flow
- [ ] Submit to `/api/analyze` as multipart/form-data
- [ ] Show loading state and error messaging for failures
- [ ] Display results matching iOS layout (totals + items)
- [ ] Verify in browser (mobile viewport)

**Integration Notes:**
- Uses: `backend/src/routes/analyze.ts`
- References: `NutritionAI/Sources/NutritionAI/Views/CameraView.swift` and `NutritionResultView.swift`

---

### US-006: History list and detail view
**Description:** As a user, I want to view my meal history and open meal details.

**Acceptance Criteria:**
- [ ] Fetch history from `/api/meals` and render most recent first
- [ ] Show thumbnails when available; show placeholders otherwise
- [ ] Tap to open detail sheet/page with full nutrition breakdown
- [ ] Guest users see local-only history or an empty state
- [ ] Verify in browser (mobile viewport)

**Integration Notes:**
- Uses: `backend/src/routes/meals.ts`
- References: `NutritionAI/Sources/NutritionAI/Views/HistoryView.swift`

---

### US-007: Settings (theme, AI model, account)
**Description:** As a user, I want to adjust theme and model settings and manage my account.

**Acceptance Criteria:**
- [ ] Theme toggle (system/light/dark) stored locally
- [ ] AI model selector matches iOS options (value sent in analyze request)
- [ ] Logout clears token and user state
- [ ] Optional admin-only backend URL override (if needed)
- [ ] Verify in browser (mobile viewport)

**Integration Notes:**
- References: `NutritionAI/Sources/NutritionAI/Views/SettingsView.swift`
- Uses: settings patterns and model list from iOS

---

### US-008: Firebase Hosting configuration
**Description:** As a developer, I want a repeatable deployment to Firebase Hosting.

**Acceptance Criteria:**
- [ ] `firebase.json` and `.firebaserc` configured for project `nutritionai2026`
- [ ] Build output deployed to Firebase Hosting
- [ ] Deployment docs specify required env vars and base URL setup
- [ ] CORS in backend allows the hosting domain

**Integration Notes:**
- Uses: Firebase project `nutritionai2026`
- References: `backend/FIREBASE_DEPLOYMENT.md`

---

### US-009: Web app testing and QA
**Description:** As a developer, I want basic tests for critical web flows.

**Acceptance Criteria:**
- [ ] Unit tests for API client and auth state
- [ ] Smoke tests for routing and key screens
- [ ] Typecheck passes

**Integration Notes:**
- New web-only tests (no changes to backend tests)

## Functional Requirements
1. Web app must support login, registration, and guest mode.
2. Web app must call existing backend endpoints with JWT auth.
3. Camera capture must support mobile browsers and fallback to upload.
4. History must show meals for authenticated users and local-only data for guests.
5. Settings must include theme toggle and AI model selection.
6. UI should follow iOS theme: gradients, glassmorphism, and typography hierarchy.
7. Web app must be deployable to Firebase Hosting in the nutritionai2026 project.

## Non-Goals
- No changes to iOS app behavior or UI in this phase.
- No new backend endpoints beyond existing API surface.
- No advanced social sharing or diet tracking features.
- No offline-first PWA or background sync (can be a future enhancement).

## Technical Considerations
- Frontend stack: React + Vite + TypeScript, mobile-first CSS (Tailwind or CSS variables).
- Token storage: localStorage (simple, consistent with current backend JWT flow).
- Use `getUserMedia` with permission handling similar to iOS camera guidance.
- Apply iOS design tokens by translating `AppTheme.swift` colors/gradients into CSS variables.
- Ensure CORS allows Firebase Hosting origin; consider allowlist in production.
- Use environment config for backend base URL, Firebase project, and API keys if needed.

## Success Metrics
- Web app provides parity for Home, Camera, History, Settings, and Auth flows.
- Time-to-first-result (upload to nutrition result) under 10 seconds on average network.
- 90% of sessions on mobile viewport complete at least one analyze flow without errors.
- No regressions in backend API tests or iOS behavior.

## Open Questions
- None (defaults applied as stated in Assumptions and Defaults).

---

## Checklist
- [ ] Reviewed existing codebase context
- [ ] Documented Integration Points
- [ ] Documented Compatibility considerations
- [ ] Stories reference existing backend and iOS files
- [ ] Non-goals prevent scope creep
- [ ] Saved to `tasks/prd-draft.md`

# PRD: User Management and Home Dashboard

## Introduction

Add user authentication, account management, and a home dashboard to the existing NutritionAI iOS app and backend. This extends the current nutrition analysis functionality by adding user accounts, login/registration, and a personalized home tab displaying user statistics and quick-capture meal options. The existing Camera, History, and Settings tabs remain unchanged.

## Goals

- Enable users to create accounts and authenticate
- Add a home dashboard tab as the default landing screen
- Display personalized stats for the logged-in user
- Provide quick-capture tiles for logging meals/partial meals
- Persist user-specific meal history and analytics
- Maintain backward compatibility with existing nutrition analysis features

## Integration Points

### Existing Components to Modify

**Backend:**
- `backend/prisma/schema.prisma` - Add User model and link MealAnalysis to users
- `backend/src/server.ts` - Add authentication middleware
- `backend/src/routes/analyze.ts` - Associate analysis with authenticated user

**iOS App:**
- `NutritionAI/Sources/NutritionAI/ContentView.swift` - Add Home tab as first tab
- `NutritionAI/Sources/NutritionAI/NutritionAIApp.swift` - Add auth state management
- `NutritionAI/Sources/NutritionAI/Services/APIService.swift` - Add auth headers to requests
- `NutritionAI/Sources/NutritionAI/Services/StorageService.swift` - Store auth tokens

### Existing Components to Reuse

**iOS App:**
- `NutritionAI/Sources/NutritionAI/Services/APIService.swift` - Extend for auth endpoints
- `NutritionAI/Sources/NutritionAI/Models/*` - Use existing models for nutrition data
- `NutritionAI/Sources/NutritionAI/Views/CameraView.swift` - Reference for quick-capture UI patterns

### New Files to Create

**Backend:**
- `backend/prisma/migrations/xxx_add_user_auth.sql` - Migration for users and auth
- `backend/src/routes/auth.ts` - Auth endpoints (register, login, logout)
- `backend/src/routes/user.ts` - User profile and stats endpoints
- `backend/src/services/auth.ts` - JWT token generation and validation
- `backend/src/middleware/auth.ts` - Authentication middleware
- `backend/src/types/auth.ts` - Auth-related TypeScript types

**iOS App:**
- `NutritionAI/Sources/NutritionAI/Views/HomeView.swift` - Home dashboard tab
- `NutritionAI/Sources/NutritionAI/Views/LoginView.swift` - Login screen
- `NutritionAI/Sources/NutritionAI/Views/RegisterView.swift` - Registration screen
- `NutritionAI/Sources/NutritionAI/Views/Components/StatsCard.swift` - User stats display
- `NutritionAI/Sources/NutritionAI/Views/Components/QuickCaptureTile.swift` - Meal capture tiles
- `NutritionAI/Sources/NutritionAI/Services/AuthService.swift` - Auth state management
- `NutritionAI/Sources/NutritionAI/Models/User.swift` - User model
- `NutritionAI/Sources/NutritionAI/Models/UserStats.swift` - User statistics model

### Database Changes

- Add `User` table with id, email, password hash, name, createdAt
- Add `userId` foreign key to `MealAnalysis` table
- Add index on `MealAnalysis.userId` for query performance
- Migration required: Yes (adds User table and modifies MealAnalysis)

## Compatibility

### Backward Compatibility

- Existing MealAnalysis records can be orphaned (userId nullable during migration)
- All existing API endpoints continue to work (analyze endpoint requires auth)
- Camera, History, and Settings tabs remain functionally identical
- Existing storage and services work without changes

### Migration Requirements

- Database migration adds User table and userId column with nullable constraint
- Existing meal analyses can optionally be migrated to a default user or remain unassociated
- JWT tokens stored securely in iOS keychain

### Deprecations

- None in this release
- Future: May require userId in all meal analyses (currently optional)

## User Stories

### US-001: Add User database model and authentication schema

**Description:** As a developer, I need to store user accounts and link meal analyses to users.

**Acceptance Criteria:**
- [ ] Add User model to Prisma schema with fields: id, email (unique), passwordHash, name, createdAt
- [ ] Add userId field to MealAnalysis (nullable for backward compatibility)
- [ ] Add index on MealAnalysis.userId for performance
- [ ] Generate and run Prisma migration successfully
- [ ] Existing tests still pass
- [ ] Typecheck passes

**Integration Notes:**
- Modifies: `backend/prisma/schema.prisma`
- Generates: New migration file
- Pattern: Follow existing Prisma patterns in schema

---

### US-002: Implement JWT authentication service

**Description:** As a backend developer, I need JWT token generation and validation for secure authentication.

**Acceptance Criteria:**
- [ ] Create auth service with generateToken and verifyToken functions
- [ ] Tokens include userId, email in payload
- [ ] Tokens expire after 30 days
- [ ] Use environment variable for JWT secret
- [ ] Hash passwords using bcrypt (add dependency)
- [ ] Typecheck passes
- [ ] Unit tests for token generation and validation

**Integration Notes:**
- Creates: `backend/src/services/auth.ts`
- Creates: `backend/src/types/auth.ts`
- New dependency: bcryptjs or argon2

---

### US-003: Create authentication middleware

**Description:** As a backend developer, I need middleware to protect authenticated routes.

**Acceptance Criteria:**
- [ ] Create auth middleware that validates JWT from Authorization header
- [ ] Attach user object to request context
- [ ] Return 401 for missing/invalid tokens
- [ ] Return 403 for expired tokens
- [ ] Typecheck passes
- [ ] Middleware tests pass

**Integration Notes:**
- Creates: `backend/src/middleware/auth.ts`
- Uses: `backend/src/services/auth.ts`
- Pattern: Follow Fastify middleware patterns

---

### US-004: Add auth endpoints (register, login)

**Description:** As a user, I want to create an account and login to access my personalized data.

**Acceptance Criteria:**
- [ ] POST /api/auth/register - creates user, returns JWT token
- [ ] POST /api/auth/login - validates credentials, returns JWT token
- [ ] Validate email format and password strength (min 8 chars)
- [ ] Return 400 for duplicate email on registration
- [ ] Return 401 for invalid credentials on login
- [ ] Typecheck passes
- [ ] API tests for both endpoints

**Integration Notes:**
- Creates: `backend/src/routes/auth.ts`
- Uses: `backend/src/services/auth.ts`
- Pattern: Follow structure of `backend/src/routes/analyze.ts`

---

### US-005: Add user stats endpoint

**Description:** As a user, I want to see my meal statistics on the home dashboard.

**Acceptance Criteria:**
- [ ] GET /api/user/stats - returns meal count, avg calories, totals
- [ ] Requires authentication (use auth middleware)
- [ ] Calculate stats from user's MealAnalysis records
- [ ] Return stats for: today, this week, all time
- [ ] Typecheck passes
- [ ] API tests for stats endpoint

**Integration Notes:**
- Creates: `backend/src/routes/user.ts`
- Uses: `backend/src/middleware/auth.ts`
- Queries: `MealAnalysis` where `userId` matches authenticated user

---

### US-006: Protect analyze endpoint with authentication

**Description:** As a developer, I need to associate meal analyses with the authenticated user.

**Acceptance Criteria:**
- [ ] Add auth middleware to POST /api/analyze route
- [ ] Store userId when creating MealAnalysis
- [ ] Return 401 if not authenticated
- [ ] Existing tests still pass (update with auth tokens)
- [ ] Typecheck passes

**Integration Notes:**
- Modifies: `backend/src/routes/analyze.ts`
- Uses: `backend/src/middleware/auth.ts`
- Breaking change: Requires authentication (document in API)

---

### US-007: Create iOS AuthService for state management

**Description:** As an iOS developer, I need centralized authentication state management.

**Acceptance Criteria:**
- [ ] Create AuthService with @Published isAuthenticated property
- [ ] Store JWT token in iOS Keychain securely
- [ ] Implement login, register, logout functions
- [ ] Auto-login on app launch if valid token exists
- [ ] Clear token on logout
- [ ] Compile and typecheck passes
- [ ] Unit tests for AuthService

**Integration Notes:**
- Creates: `NutritionAI/Sources/NutritionAI/Services/AuthService.swift`
- Uses: iOS Keychain API for secure storage
- Pattern: Follow structure of existing StorageService.swift

---

### US-008: Create User and UserStats models

**Description:** As an iOS developer, I need Swift models for user data.

**Acceptance Criteria:**
- [ ] Create User model matching backend (id, email, name)
- [ ] Create UserStats model (todayMeals, weekMeals, avgCalories, etc.)
- [ ] Both models conform to Codable
- [ ] Compile and typecheck passes

**Integration Notes:**
- Creates: `NutritionAI/Sources/NutritionAI/Models/User.swift`
- Creates: `NutritionAI/Sources/NutritionAI/Models/UserStats.swift`
- Pattern: Follow existing Models/MealAnalysis.swift structure

---

### US-009: Update APIService with authentication

**Description:** As a developer, I need API calls to include authentication headers.

**Acceptance Criteria:**
- [ ] Add Authorization header with Bearer token to all requests
- [ ] Add register() and login() API methods
- [ ] Add fetchUserStats() API method
- [ ] Handle 401 responses by triggering logout
- [ ] Existing API methods still work
- [ ] Compile and typecheck passes

**Integration Notes:**
- Modifies: `NutritionAI/Sources/NutritionAI/Services/APIService.swift`
- Uses: AuthService to get current token
- Existing tests still pass

---

### US-010: Create Login and Register views

**Description:** As a user, I want to login or create an account from the app.

**Acceptance Criteria:**
- [ ] LoginView with email and password fields
- [ ] RegisterView with email, name, password, confirm password fields
- [ ] Both views show loading state during API calls
- [ ] Show error messages for failed auth
- [ ] Navigate to main app on successful auth
- [ ] Link between Login and Register views
- [ ] Compile and typecheck passes
- [ ] Verify in iOS Simulator

**Integration Notes:**
- Creates: `NutritionAI/Sources/NutritionAI/Views/LoginView.swift`
- Creates: `NutritionAI/Sources/NutritionAI/Views/RegisterView.swift`
- Uses: AuthService and APIService
- Pattern: SwiftUI forms similar to SettingsView

---

### US-011: Create StatsCard component for dashboard

**Description:** As a user, I want to see my nutrition stats in visually clear cards.

**Acceptance Criteria:**
- [ ] Reusable StatsCard component with title, value, subtitle
- [ ] Support different stat types (count, calories, macros)
- [ ] Clean, card-based design with system colors
- [ ] Responsive layout in grid
- [ ] Compile and typecheck passes
- [ ] Verify in iOS Simulator

**Integration Notes:**
- Creates: `NutritionAI/Sources/NutritionAI/Views/Components/StatsCard.swift`
- Pattern: Follow SwiftUI component best practices
- Design: Use system fonts and SF Symbols

---

### US-012: Create QuickCaptureTile component

**Description:** As a user, I want quick-access tiles to capture full meals or partial meals.

**Acceptance Criteria:**
- [ ] QuickCaptureTile component with icon, label, and action
- [ ] Tappable tile that triggers camera or specific capture flow
- [ ] Support for "Full Meal", "Snack", "Quick Add" options
- [ ] Visual feedback on tap
- [ ] Compile and typecheck passes
- [ ] Verify in iOS Simulator

**Integration Notes:**
- Creates: `NutritionAI/Sources/NutritionAI/Views/Components/QuickCaptureTile.swift`
- Will trigger: Navigation to CameraView or custom capture flow
- Design: Card-based UI with SF Symbols

---

### US-013: Create HomeView dashboard

**Description:** As a user, I want a home dashboard showing my stats and quick meal capture options.

**Acceptance Criteria:**
- [ ] Display welcome message with user's name
- [ ] Show stats grid with today/week/total meals and calories
- [ ] Show quick capture tiles for Full Meal, Snack, Quick Add
- [ ] Refresh stats when view appears
- [ ] Show loading state while fetching stats
- [ ] Show empty state for new users
- [ ] Compile and typecheck passes
- [ ] Verify in iOS Simulator

**Integration Notes:**
- Creates: `NutritionAI/Sources/NutritionAI/Views/HomeView.swift`
- Uses: StatsCard, QuickCaptureTile components
- Uses: APIService.fetchUserStats()
- Uses: AuthService for user info

---

### US-014: Add HomeView to TabView and update app flow

**Description:** As a user, I want the Home tab to be the first tab when I open the app.

**Acceptance Criteria:**
- [ ] Add HomeView as first tab in TabView
- [ ] Show login screen if not authenticated
- [ ] Show main TabView with Home tab if authenticated
- [ ] Home tab uses "house.fill" SF Symbol
- [ ] Existing tabs (Camera, History, Settings) still work
- [ ] Tab order: Home, Camera, History, Settings
- [ ] Compile and typecheck passes
- [ ] Verify in iOS Simulator

**Integration Notes:**
- Modifies: `NutritionAI/Sources/NutritionAI/ContentView.swift`
- Modifies: `NutritionAI/Sources/NutritionAI/NutritionAIApp.swift`
- Uses: AuthService to check auth state
- Pattern: Conditional view rendering based on auth

---

### US-015: Add logout functionality to Settings

**Description:** As a user, I want to logout from my account in the Settings tab.

**Acceptance Criteria:**
- [ ] Add "Logout" button to SettingsView
- [ ] Tapping logout clears auth token and returns to login
- [ ] Show confirmation dialog before logout
- [ ] Existing settings functionality still works
- [ ] Compile and typecheck passes
- [ ] Verify in iOS Simulator

**Integration Notes:**
- Modifies: `NutritionAI/Sources/NutritionAI/Views/SettingsView.swift`
- Uses: AuthService.logout()
- Existing tests still pass

---

## Functional Requirements

**Authentication:**
- FR-1: Users must register with email, name, and password (min 8 characters)
- FR-2: Passwords hashed using bcrypt before storage
- FR-3: JWT tokens valid for 30 days
- FR-4: Tokens stored securely in iOS Keychain
- FR-5: All API requests (except auth endpoints) require valid JWT

**Home Dashboard:**
- FR-6: Home tab displays: user name, today's meals count, week's meals count, average calories
- FR-7: Stats refresh automatically when HomeView appears
- FR-8: Quick capture tiles: "Full Meal" (opens camera), "Snack" (opens camera), "Quick Add" (future feature)

**User Data:**
- FR-9: MealAnalysis records linked to authenticated user via userId
- FR-10: History view shows only current user's meal analyses
- FR-11: Stats calculated from user's MealAnalysis records only

**UI/UX:**
- FR-12: Unauthenticated users see login screen on app launch
- FR-13: Authenticated users see Home tab by default
- FR-14: Tab order: Home, Camera, History, Settings
- FR-15: Logout option available in Settings tab

## Non-Goals (Out of Scope)

- Social features or sharing meals between users
- Password reset/forgot password flow (future enhancement)
- Email verification (future enhancement)
- OAuth/social login (Google, Apple Sign-In)
- Profile editing (name, email changes)
- Multi-device sync beyond JWT auth
- Detailed nutrition goals or tracking
- "Quick Add" manual entry (tile placeholder only)
- Admin panel or user management tools
- Rate limiting beyond existing @fastify/rate-limit

## Technical Considerations

**Backend:**
- Add `bcryptjs` dependency for password hashing
- Add `jsonwebtoken` dependency for JWT handling
- Use environment variable `JWT_SECRET` for token signing
- Fastify authentication hooks for protected routes
- Database indexes on User.email and MealAnalysis.userId

**iOS:**
- Use iOS Keychain for secure token storage
- SwiftUI @EnvironmentObject for AuthService
- Handle 401 responses globally to trigger logout
- Maintain existing Xcode project structure
- No new third-party dependencies required

**Testing:**
- Backend: Add auth tests to `backend/src/__tests__/`
- iOS: Add tests to `Tests/NutritionAITests/`
- Test auth flows: register, login, logout, protected endpoints
- Test stats calculations with various data

**Performance:**
- Stats queries optimized with userId index
- Token verification cached during request lifecycle
- JWT expiration reduces database lookups

## Success Metrics

- Users can register and login in under 30 seconds
- Home dashboard loads stats in under 2 seconds
- All existing nutrition analysis features work unchanged
- Zero regression in existing test suite
- JWT tokens securely stored and transmitted
- Password hashes never exposed in API responses

## Open Questions

1. **Migration Strategy:** Should existing orphaned MealAnalysis records be assigned to a default user or remain unassociated?
   - **Default Answer:** Leave as nullable (orphaned). Future feature can claim/import.

2. **Token Refresh:** Should we implement refresh tokens or rely on 30-day expiration?
   - **Default Answer:** 30-day expiration for MVP, refresh tokens in future enhancement.

3. **Password Requirements:** Beyond 8 characters, should we enforce complexity (uppercase, numbers, symbols)?
   - **Default Answer:** Minimum 8 characters only for MVP.

4. **Quick Capture Actions:** How should "Snack" differ from "Full Meal" capture?
   - **Default Answer:** Both open camera for MVP, future can add meal type tags.

5. **Stats Time Zones:** How should "today" be calculated (device timezone, UTC, user preference)?
   - **Default Answer:** Use device timezone for client-side filtering.

6. **Offline Support:** Should users be able to capture meals offline?
   - **Default Answer:** No offline support in MVP, future enhancement.

---

## Story Implementation Order

Follow this order to minimize integration risk:

1. **US-001** - Database schema changes (foundation)
2. **US-002** - Auth service (needed by all backend)
3. **US-003** - Auth middleware (protects routes)
4. **US-004** - Auth endpoints (register/login)
5. **US-005** - User stats endpoint
6. **US-006** - Protect analyze endpoint
7. **US-008** - iOS models (User, UserStats)
8. **US-007** - iOS AuthService
9. **US-009** - Update APIService with auth
10. **US-010** - Login/Register views
11. **US-011** - StatsCard component
12. **US-012** - QuickCaptureTile component
13. **US-013** - HomeView dashboard
14. **US-014** - Integrate HomeView into app
15. **US-015** - Add logout to Settings

---

## Dependencies to Add

**Backend (package.json):**
```json
{
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2"
  },
  "devDependencies": {
    "@types/bcryptjs": "^2.4.6",
    "@types/jsonwebtoken": "^9.0.5"
  }
}
```

**iOS:**
- No new external dependencies (use native Keychain API)

---

**END OF PRD**

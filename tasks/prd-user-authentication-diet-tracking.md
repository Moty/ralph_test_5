# PRD: User Authentication, Diet Preferences & Social Sharing

## Introduction

Add comprehensive user management, diet tracking, and social sharing features to the existing NutritionAI app. This extends the current food analysis functionality with user authentication, personalized diet preferences (keto, paleo, vegan, etc.), meal consumption tracking, diet goal scoring, trend analytics, weight tracking, and social sharing capabilities. The backend will be enhanced to support concurrent multi-user operations.

## Goals

- Enable user registration and login with persistent user sessions
- Allow users to set and manage diet preferences (keto, paleo, vegan, etc.)
- Provide diet compatibility scoring for each analyzed meal
- Track consumed meals vs. analyzed meals with editing capability
- Display eating trends based on diet goals and custom metrics
- Support daily weight tracking and ketone level monitoring
- Enable sharing results via social media, link, SMS, and iOS native sharing
- Create an engaging home page with personalized branding
- Design creative app icon and tile featuring Nutrition AI branding
- Scale backend to handle concurrent multi-user requests efficiently

## Integration Points

### Existing Components to Modify

#### iOS App (NutritionAIApp/)
- `NutritionAIApp/NutritionAIApp/NutritionAIAppApp.swift` - Add authentication state management
- `NutritionAIApp/NutritionAIApp/ContentView.swift` - Replace with authenticated home page or login screen
- `Sources/NutritionAI/Views/CameraView.swift` - Add meal tagging (consumed vs. scanned)
- `Sources/NutritionAI/Views/NutritionResultView.swift` - Add diet score, edit capability, share button
- `Sources/NutritionAI/Views/HistoryView.swift` - Filter consumed meals, add trend visualization
- `Sources/NutritionAI/Services/APIService.swift` - Add authentication headers, user endpoints
- `Sources/NutritionAI/Services/StorageService.swift` - Store user session, associate meals with user
- `Sources/NutritionAI/Models/MealAnalysis.swift` - Add consumed flag, diet score, custom tags
- `Info.plist` - Add PhotoKit permissions for sharing

#### Backend (backend/)
- `backend/prisma/schema.prisma` - Add User, UserProfile, DailyMetrics models
- `backend/src/server.ts` - Add authentication middleware, session management
- `backend/src/routes/analyze.ts` - Use authenticated userId instead of placeholder
- Database models require comprehensive schema additions

### Existing Components to Reuse
- `Sources/NutritionAI/Services/APIService.swift` - Extend for new auth/user endpoints
- `Sources/NutritionAI/Models/NutritionData.swift` - Use for diet scoring calculations
- `backend/src/services/gemini.js` - Extend prompts for diet compatibility analysis
- Existing Fastify plugins (CORS, rate-limit, multipart)
- Existing Prisma client setup with PostgreSQL adapter

### New Files to Create

#### iOS App
- `Sources/NutritionAI/Views/HomeView.swift` - Welcome home page with app branding
- `Sources/NutritionAI/Views/Auth/LoginView.swift` - User login screen
- `Sources/NutritionAI/Views/Auth/RegisterView.swift` - User registration screen
- `Sources/NutritionAI/Views/Profile/ProfileView.swift` - User profile and diet preferences
- `Sources/NutritionAI/Views/Profile/DietPreferencesView.swift` - Diet goals selection
- `Sources/NutritionAI/Views/Trends/TrendsView.swift` - Diet trends and analytics
- `Sources/NutritionAI/Views/Trends/WeightTrackingView.swift` - Daily weight entry
- `Sources/NutritionAI/Views/Components/DietScoreBadge.swift` - Diet compatibility indicator
- `Sources/NutritionAI/Views/Components/ShareSheet.swift` - iOS native sharing
- `Sources/NutritionAI/Services/AuthService.swift` - Authentication and session management
- `Sources/NutritionAI/Services/DietScoringService.swift` - Calculate diet compatibility
- `Sources/NutritionAI/Services/ShareService.swift` - Generate shareable content
- `Sources/NutritionAI/Models/User.swift` - User model
- `Sources/NutritionAI/Models/UserProfile.swift` - Profile with diet preferences
- `Sources/NutritionAI/Models/DailyMetrics.swift` - Weight, ketone levels
- `Sources/NutritionAI/Models/DietType.swift` - Enum for diet preferences
- `Assets.xcassets/AppIcon.appiconset/` - New creative Nutrition AI icon
- `Assets.xcassets/AppTile.imageset/` - App tile image

#### Backend
- `backend/src/routes/auth.ts` - Registration, login, logout endpoints
- `backend/src/routes/users.ts` - User profile and preferences endpoints
- `backend/src/routes/meals.ts` - Meal tagging, editing, retrieval
- `backend/src/routes/metrics.ts` - Daily weight, ketone tracking endpoints
- `backend/src/routes/trends.ts` - Analytics and trend calculation
- `backend/src/services/auth.ts` - JWT token generation/validation
- `backend/src/services/dietScoring.ts` - Diet compatibility algorithm
- `backend/src/services/trends.ts` - Trend calculation logic
- `backend/src/middleware/authenticate.ts` - Auth middleware for protected routes
- `backend/src/types/auth.d.ts` - Authentication types
- `backend/src/types/user.d.ts` - User-related types
- `backend/prisma/migrations/xxx_add_users_and_profiles.sql` - Migration file
- `backend/src/__tests__/auth.test.ts` - Authentication tests
- `backend/src/__tests__/meals.test.ts` - Meal tracking tests

### Database Changes

#### New Tables/Models
- **User** table: id, email, passwordHash, createdAt, updatedAt
- **UserProfile** table: id, userId (FK), displayName, dietPreference, dailyCalorieGoal, createdAt, updatedAt
- **Meal** table: Extends MealAnalysis with isConsumed, dietScore, customNotes, tags
- **DailyMetrics** table: id, userId (FK), date, weight, ketoneLevel, notes, createdAt
- **SharedLink** table: id, userId (FK), mealId (FK), shareToken, expiresAt, createdAt

#### Modified Tables
- **MealAnalysis**: Add userId (indexed, FK), isConsumed boolean, dietScore float, customNotes text, tags array

#### Indexes Required
- User.email (unique)
- MealAnalysis.userId + createdAt (for efficient user meal queries)
- DailyMetrics.userId + date (unique composite, for trend queries)
- SharedLink.shareToken (unique, for link resolution)

Migration required: Yes (adds new tables and modifies existing MealAnalysis)

## Compatibility

### Backward Compatibility
- Existing MealAnalysis records will have userId set to NULL initially (updated via data migration)
- Existing meals default to isConsumed=false, dietScore=null
- All existing `/api/analyze` calls continue to work for authenticated users
- Health check endpoint remains unauthenticated

### Migration Requirements
- Database migration adds User, UserProfile, DailyMetrics, SharedLink tables
- Adds new columns to MealAnalysis with nullable defaults
- Create default "legacy" user and associate existing meals (optional)
- Generate Prisma client after schema changes
- No API breaking changes - new endpoints are additive

### Authentication Strategy
- JWT-based authentication with HTTP-only cookies (web) or Authorization header (iOS)
- Session expiration: 30 days with refresh token support
- Password hashing: bcrypt with salt rounds = 10
- Rate limiting on auth endpoints: 5 attempts per 15 minutes

### Deprecations
- Placeholder userId 'placeholder-user-id' will be removed after migration
- Non-authenticated analysis requests will require login (breaking change for existing clients)

## User Stories

### US-001: Database Schema for Users and Profiles
**Description:** As a developer, I need to store user accounts and diet preferences so the system can personalize experiences.

**Acceptance Criteria:**
- [ ] Add User model to Prisma schema with email (unique), passwordHash, timestamps
- [ ] Add UserProfile model with userId FK, displayName, dietPreference enum, dailyCalorieGoal
- [ ] Add DailyMetrics model with userId FK, date, weight, ketoneLevel, notes
- [ ] Add SharedLink model for shareable meal links
- [ ] Modify MealAnalysis to include userId FK, isConsumed, dietScore, customNotes, tags
- [ ] Create and test migration successfully on dev database
- [ ] Generate updated Prisma client
- [ ] Existing tests still pass
- [ ] Typecheck passes

**Integration Notes:**
- Modifies: `backend/prisma/schema.prisma`
- Generates: New migration file `backend/prisma/migrations/xxx_add_users_and_profiles.sql`
- Updates: Prisma client types

### US-002: Backend User Registration Endpoint
**Description:** As a new user, I want to register with email and password so I can create an account.

**Acceptance Criteria:**
- [ ] POST `/api/auth/register` endpoint accepts email, password, displayName
- [ ] Validates email format and password strength (min 8 chars)
- [ ] Hashes password with bcrypt before storing
- [ ] Creates User and UserProfile records in transaction
- [ ] Returns JWT token and user profile on success
- [ ] Returns 400 if email already exists
- [ ] Rate limit: 5 requests per 15 minutes per IP
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Unit tests for registration flow

**Integration Notes:**
- Creates: `backend/src/routes/auth.ts`, `backend/src/services/auth.ts`
- Creates: `backend/src/types/auth.d.ts`
- Uses: Existing Prisma client, bcrypt library (new dependency)
- Pattern: Follow existing route structure from `analyze.ts`

### US-003: Backend User Login Endpoint
**Description:** As a returning user, I want to login with my credentials so I can access my data.

**Acceptance Criteria:**
- [ ] POST `/api/auth/login` endpoint accepts email, password
- [ ] Validates credentials against stored hash
- [ ] Returns JWT token with 30-day expiration on success
- [ ] Returns 401 for invalid credentials
- [ ] Returns user profile with token
- [ ] Rate limit: 5 requests per 15 minutes per IP
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Unit tests for login flow

**Integration Notes:**
- Modifies: `backend/src/routes/auth.ts`
- Uses: `backend/src/services/auth.ts` for JWT generation
- Uses: Existing Prisma client
- New dependency: jsonwebtoken library

### US-004: Backend Authentication Middleware
**Description:** As a developer, I need to protect API endpoints so only authenticated users can access their data.

**Acceptance Criteria:**
- [ ] Create middleware to verify JWT tokens from Authorization header
- [ ] Attach userId to request object for downstream handlers
- [ ] Return 401 for missing or invalid tokens
- [ ] Support token refresh mechanism
- [ ] Apply to all protected routes (analyze, meals, metrics, trends)
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Unit tests for middleware

**Integration Notes:**
- Creates: `backend/src/middleware/authenticate.ts`
- Modifies: `backend/src/server.ts` to register middleware
- Modifies: `backend/src/routes/analyze.ts` to use authenticated userId

### US-005: iOS User Registration Screen
**Description:** As a new user, I want a registration screen so I can create an account from my iPhone.

**Acceptance Criteria:**
- [ ] Create RegisterView with email, password, display name fields
- [ ] Validate email format before submission
- [ ] Show password strength indicator
- [ ] Call `/api/auth/register` endpoint
- [ ] Store JWT token in Keychain on success
- [ ] Navigate to home page after successful registration
- [ ] Display validation errors inline
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Creates: `Sources/NutritionAI/Views/Auth/RegisterView.swift`
- Creates: `Sources/NutritionAI/Services/AuthService.swift`
- Uses: Existing APIService pattern for networking
- New: Keychain storage for secure token persistence

### US-006: iOS User Login Screen
**Description:** As a returning user, I want a login screen so I can access my account.

**Acceptance Criteria:**
- [ ] Create LoginView with email and password fields
- [ ] Call `/api/auth/login` endpoint
- [ ] Store JWT token in Keychain on success
- [ ] Navigate to home page after successful login
- [ ] Show error message for invalid credentials
- [ ] Support "Remember me" functionality
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Creates: `Sources/NutritionAI/Views/Auth/LoginView.swift`
- Uses: `Sources/NutritionAI/Services/AuthService.swift`
- Uses: Existing APIService pattern

### US-007: iOS Home Page with Branding
**Description:** As a user, I want an engaging home page so I understand the app's value.

**Acceptance Criteria:**
- [ ] Create HomeView with Nutrition AI branding and tagline
- [ ] Show Register and Login buttons for unauthenticated users
- [ ] Show personalized greeting and quick stats for authenticated users
- [ ] Display today's meal summary (consumed calories, macros)
- [ ] Quick action buttons: Analyze Food, View History, Track Weight
- [ ] Support dark mode with adaptive colors
- [ ] Smooth animations on load
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Creates: `Sources/NutritionAI/Views/HomeView.swift`
- Modifies: `NutritionAIApp/NutritionAIApp/ContentView.swift` to show HomeView based on auth state
- Uses: AuthService to determine authentication state

### US-008: Creative App Icon and Tile
**Description:** As a user, I want a visually appealing app icon so the app stands out on my home screen.

**Acceptance Criteria:**
- [ ] Design creative Nutrition AI icon featuring food/health imagery
- [ ] Create icon in all required iOS sizes (1024x1024 base, plus @2x, @3x variants)
- [ ] Add app tile image for marketing materials
- [ ] Use vibrant colors aligned with health/nutrition theme
- [ ] Icon visible and crisp on all iOS devices
- [ ] Update Assets.xcassets with new icon
- [ ] Existing tests still pass
- [ ] Verify icon in simulator and test device

**Integration Notes:**
- Creates: `Assets.xcassets/AppIcon.appiconset/` with all required sizes
- Creates: `Assets.xcassets/AppTile.imageset/`
- Tool: Design with SF Symbols, Figma, or similar
- Note: May require designer collaboration or AI image generation

### US-009: User Profile with Diet Preferences
**Description:** As a user, I want to set my diet preference so meal analysis matches my goals.

**Acceptance Criteria:**
- [ ] Create ProfileView showing user info and diet preference
- [ ] Diet preference options: Keto, Paleo, Vegan, Vegetarian, Mediterranean, Low-Carb, Balanced, Custom
- [ ] Allow setting daily calorie goal
- [ ] Save preferences via PUT `/api/users/profile` endpoint
- [ ] Display current weight and ketone level (if keto)
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Creates: `Sources/NutritionAI/Views/Profile/ProfileView.swift`
- Creates: `Sources/NutritionAI/Views/Profile/DietPreferencesView.swift`
- Creates: `Sources/NutritionAI/Models/DietType.swift` enum
- Backend: `backend/src/routes/users.ts` for profile endpoints

### US-010: Backend Diet Compatibility Scoring
**Description:** As a system, I need to calculate how well a meal fits a user's diet so users see relevant scores.

**Acceptance Criteria:**
- [ ] Create diet scoring algorithm based on macro ratios
- [ ] Keto: High fat (70%+), low carb (<10%), moderate protein
- [ ] Paleo: Whole foods, no processed sugars, no grains
- [ ] Vegan: No animal products
- [ ] Return score 0-100 for each analyzed meal
- [ ] Include scoring explanation in response
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Unit tests for scoring algorithms

**Integration Notes:**
- Creates: `backend/src/services/dietScoring.ts`
- Modifies: `backend/src/routes/analyze.ts` to calculate score on analysis
- Uses: User's dietPreference from UserProfile
- Stores: Score in MealAnalysis.dietScore

### US-011: iOS Diet Score Display
**Description:** As a user, I want to see how well each meal fits my diet so I can make informed choices.

**Acceptance Criteria:**
- [ ] Display diet score badge (0-100) on NutritionResultView
- [ ] Color code: Green (80-100), Yellow (60-79), Red (0-59)
- [ ] Show scoring explanation text
- [ ] Display score in HistoryView meal items
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Creates: `Sources/NutritionAI/Views/Components/DietScoreBadge.swift`
- Modifies: `Sources/NutritionAI/Views/NutritionResultView.swift`
- Modifies: `Sources/NutritionAI/Views/HistoryView.swift`
- Uses: DietScoringService for local calculations if needed

### US-012: Tag Meals as Consumed
**Description:** As a user, I want to mark meals as actually consumed so I can track what I ate vs. what I scanned.

**Acceptance Criteria:**
- [ ] Add "Mark as Consumed" toggle in NutritionResultView
- [ ] POST `/api/meals/:id/consume` endpoint to update isConsumed flag
- [ ] Allow adding custom notes when marking consumed
- [ ] Filter HistoryView to show consumed vs. scanned meals
- [ ] Visual indicator (checkmark) on consumed meals
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Modifies: `Sources/NutritionAI/Views/NutritionResultView.swift`
- Modifies: `Sources/NutritionAI/Views/HistoryView.swift`
- Creates: `backend/src/routes/meals.ts` with consume endpoint
- Modifies: `Sources/NutritionAI/Models/MealAnalysis.swift` to include isConsumed

### US-013: Edit Consumed Meal Details
**Description:** As a user, I want to edit meal details if the analysis differs from what I actually ate.

**Acceptance Criteria:**
- [ ] Add "Edit Meal" button on NutritionResultView for consumed meals
- [ ] Allow editing food items, portions, and nutrition values
- [ ] PUT `/api/meals/:id` endpoint to update meal data
- [ ] Show edited indicator on modified meals
- [ ] Validate nutrition data before saving
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Creates: `Sources/NutritionAI/Views/EditMealView.swift`
- Modifies: `backend/src/routes/meals.ts` with update endpoint
- Uses: Existing NutritionData models for editing

### US-014: Daily Weight Tracking
**Description:** As a user, I want to log my daily weight so I can track progress over time.

**Acceptance Criteria:**
- [ ] Create WeightTrackingView with date picker and weight input
- [ ] POST `/api/metrics/weight` endpoint to save weight entry
- [ ] GET `/api/metrics/weight?days=30` to retrieve history
- [ ] Display weight trend chart (line graph)
- [ ] Allow adding notes to weight entries
- [ ] Support kg and lbs units
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Creates: `Sources/NutritionAI/Views/Trends/WeightTrackingView.swift`
- Creates: `backend/src/routes/metrics.ts`
- Creates: `Sources/NutritionAI/Models/DailyMetrics.swift`
- Consider: Swift Charts framework for visualization

### US-015: Ketone Level Tracking (Keto Users)
**Description:** As a keto user, I want to track my ketone levels so I know if I'm in ketosis.

**Acceptance Criteria:**
- [ ] Add ketone level field to WeightTrackingView (shown only for keto users)
- [ ] Save ketone level in DailyMetrics table
- [ ] Display ketone trend chart
- [ ] Show "In Ketosis" indicator when level > 0.5 mmol/L
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Modifies: `Sources/NutritionAI/Views/Trends/WeightTrackingView.swift`
- Conditional display based on user's dietPreference = keto
- Uses: DailyMetrics.ketoneLevel field

### US-016: Eating Trends Dashboard
**Description:** As a user, I want to see my eating trends so I understand my nutrition patterns.

**Acceptance Criteria:**
- [ ] Create TrendsView showing 7-day and 30-day summaries
- [ ] Display average daily calories, macros (protein, carbs, fat)
- [ ] Show diet score trend over time
- [ ] Highlight best and worst scoring meals
- [ ] GET `/api/trends?period=7d` endpoint for trend calculations
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Creates: `Sources/NutritionAI/Views/Trends/TrendsView.swift`
- Creates: `backend/src/routes/trends.ts`
- Creates: `backend/src/services/trends.ts` for calculations
- Uses: Swift Charts for visualization

### US-017: Social Media Sharing
**Description:** As a user, I want to share my meal results on social media so I can celebrate my progress.

**Acceptance Criteria:**
- [ ] Add "Share" button on NutritionResultView
- [ ] Generate shareable image with meal photo, nutrition summary, diet score
- [ ] Support sharing to: Instagram, Facebook, Twitter, generic image share
- [ ] Include app branding on shared image
- [ ] Support dark mode
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Creates: `Sources/NutritionAI/Services/ShareService.swift`
- Uses: UIActivityViewController for iOS sharing
- Generates: Composite image with meal data overlay
- Consider: Social media SDK integration (optional)

### US-018: Shareable Link Generation
**Description:** As a user, I want to generate a shareable link so others can view my meal without the app.

**Acceptance Criteria:**
- [ ] POST `/api/share/meal/:id` creates shareable link with expiration (7 days)
- [ ] Returns unique URL: `https://nutritionai.app/shared/{token}`
- [ ] GET `/api/share/{token}` returns meal data for public viewing
- [ ] Link expires after 7 days
- [ ] Track view count on shared links (optional)
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Unit tests for link generation

**Integration Notes:**
- Creates: `backend/src/routes/share.ts`
- Uses: SharedLink table for token storage
- Public endpoint (no auth required) for viewing shared meals

### US-019: iOS Native Sharing (SMS, Email, AirDrop)
**Description:** As a user, I want to share via SMS or AirDrop so I can send results to friends easily.

**Acceptance Criteria:**
- [ ] Integrate UIActivityViewController for native iOS sharing
- [ ] Share includes: Meal image, text summary, optional link
- [ ] Text format: "I had [meal] with [calories] calories! [app link]"
- [ ] Support SMS, email, AirDrop, clipboard
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator and device

**Integration Notes:**
- Creates: `Sources/NutritionAI/Views/Components/ShareSheet.swift`
- Uses: SwiftUI UIViewControllerRepresentable wrapper
- Generates: Shareable content via ShareService

### US-020: Backend Concurrency and Connection Pooling
**Description:** As a system, I need to handle multiple concurrent users so the app scales properly.

**Acceptance Criteria:**
- [ ] Configure PostgreSQL connection pool with min 5, max 20 connections
- [ ] Add database query timeout (10 seconds)
- [ ] Implement request queuing for high load scenarios
- [ ] Add health check endpoint for database connectivity
- [ ] Load test with 50 concurrent users
- [ ] Response time under 2 seconds for 95th percentile
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Load tests pass

**Integration Notes:**
- Modifies: `backend/src/routes/analyze.ts` Prisma pool configuration
- Modifies: `backend/src/server.ts` for connection settings
- Uses: Existing pg.Pool configuration
- Tool: Artillery or k6 for load testing
- Monitor: Connection pool stats in logs

### US-021: Session Management and Auto-Login
**Description:** As a user, I want to stay logged in so I don't have to authenticate every time.

**Acceptance Criteria:**
- [ ] Store JWT token in iOS Keychain securely
- [ ] Auto-load token on app launch
- [ ] Validate token with backend on startup
- [ ] Redirect to login if token expired or invalid
- [ ] Support logout to clear session
- [ ] Existing tests still pass
- [ ] Typecheck passes
- [ ] Verify in simulator

**Integration Notes:**
- Modifies: `Sources/NutritionAI/Services/AuthService.swift`
- Modifies: `NutritionAIApp/NutritionAIApp/NutritionAIAppApp.swift` for initialization
- Uses: KeychainAccess library or native Keychain API

## Functional Requirements

### Authentication & User Management
- FR-1: Users register with email, password (min 8 chars), and display name
- FR-2: Passwords hashed with bcrypt before storage
- FR-3: JWT tokens expire after 30 days with refresh support
- FR-4: Rate limiting on auth endpoints: 5 attempts per 15 minutes
- FR-5: Email validation enforced (proper format, unique)
- FR-6: Sessions persist in iOS Keychain for auto-login

### Diet Preferences
- FR-7: Supported diets: Keto, Paleo, Vegan, Vegetarian, Mediterranean, Low-Carb, Balanced, Custom
- FR-8: Each user has one active diet preference
- FR-9: Users can set daily calorie goals
- FR-10: Diet preference used for all meal scoring

### Meal Analysis & Scoring
- FR-11: All analyzed meals associated with authenticated user
- FR-12: Diet score (0-100) calculated for each meal based on user's preference
- FR-13: Scoring explanation included in analysis response
- FR-14: Meals can be marked as consumed with optional notes
- FR-15: Consumed meals editable (portions, items, nutrition values)

### Tracking & Metrics
- FR-16: Daily weight tracking with date, value, notes
- FR-17: Ketone level tracking for keto users
- FR-18: Weight/ketone data stored per user per day (unique constraint)
- FR-19: Support kg and lbs units for weight

### Trends & Analytics
- FR-20: 7-day and 30-day trend summaries
- FR-21: Average calories and macros calculated from consumed meals only
- FR-22: Diet score trends over time
- FR-23: Best/worst scoring meals highlighted

### Sharing
- FR-24: Generate shareable image with meal data and branding
- FR-25: Support iOS native sharing (SMS, email, AirDrop, social)
- FR-26: Shareable links expire after 7 days
- FR-27: Public viewing of shared meals (no auth required)

### Backend Scalability
- FR-28: Connection pool supports 5-20 concurrent PostgreSQL connections
- FR-29: Database queries timeout after 10 seconds
- FR-30: All protected endpoints require valid JWT authentication
- FR-31: Existing rate limiting maintained (100 req/hour general, 5 req/15min auth)

### UI/UX
- FR-32: Dark mode support across all new views
- FR-33: Creative app icon with Nutrition AI branding
- FR-34: Home page shows personalized content for authenticated users
- FR-35: Registration/login screens for unauthenticated users

## Non-Goals (Out of Scope)

- Social features (following users, comments, likes)
- Recipe recommendations or meal planning
- Integration with fitness trackers (Apple Health, Fitbit)
- Barcode scanning for packaged foods
- Calorie budgeting or meal scheduling
- Multi-language support (English only for now)
- Password reset via email (future enhancement)
- Two-factor authentication (future enhancement)
- Admin dashboard for user management
- Analytics tracking (Mixpanel, Amplitude)
- Push notifications for daily reminders
- Subscription or payment integration
- OCR for nutrition labels
- Voice input for meal logging
- Meal photo gallery beyond history
- Export data to CSV/PDF

## Technical Considerations

### Architecture & Patterns
- Follow existing Fastify route structure for new backend endpoints
- Use existing SwiftUI view patterns for consistency
- Maintain Prisma ORM for all database operations
- Continue using async/await throughout for async operations
- Apply existing error handling patterns (user-friendly messages, sanitized errors)

### Security
- Store passwords with bcrypt (salt rounds = 10)
- Use JWT tokens with secure signing key (env variable)
- Store tokens in iOS Keychain (not UserDefaults)
- Validate all user inputs on backend
- Sanitize error messages to avoid leaking internal details
- Use prepared statements via Prisma (prevents SQL injection)

### Performance
- Index userId + createdAt on MealAnalysis for efficient queries
- Use connection pooling to handle concurrent requests
- Lazy load meal history (pagination support)
- Optimize trend calculations with database aggregations
- Cache user profile in memory during session (iOS)
- Compress shared images before upload

### Testing Strategy
- Unit tests for authentication flow (register, login, token validation)
- Unit tests for diet scoring algorithms
- Integration tests for new API endpoints
- UI tests for critical flows (registration, login, meal tagging)
- Load tests for backend concurrency (50+ concurrent users)
- Manual testing in simulator and physical device
- Test dark mode across all new views

### Dependencies
**New Backend:**
- bcrypt: Password hashing
- jsonwebtoken: JWT generation/validation
- (Optional) express-rate-limit: Additional auth rate limiting

**New iOS:**
- KeychainAccess (or native Keychain API): Secure token storage
- (Optional) Charts framework: Trend visualization
- (Optional) Social media SDKs: Direct social sharing

### Database Migration Strategy
1. Run migration to add new tables (User, UserProfile, DailyMetrics, SharedLink)
2. Add new columns to MealAnalysis (nullable initially)
3. Optional: Create "legacy" user and associate existing meals
4. Deploy backend with backward compatibility
5. Update iOS app to require authentication
6. Monitor logs for migration issues

### Rollback Plan
- Database migration reversible via down migration
- Feature flags for authentication requirement (allow anonymous access temporarily)
- Backend API versioning (/v1/api/analyze vs /v2/api/analyze)
- iOS app version check to enforce minimum backend version

## Success Metrics

### User Engagement
- 80%+ of users set a diet preference within first session
- 60%+ of analyzed meals marked as consumed
- 40%+ of users track weight at least 3x per week

### Performance
- 95th percentile response time < 2 seconds for all endpoints
- Support 50+ concurrent users without degradation
- Zero authentication failures due to backend errors

### Quality
- All existing tests continue to pass
- Zero critical bugs in authentication flow
- 90%+ code coverage on new backend services
- App Store rating maintains 4.0+ stars

### Adoption
- 70%+ of users register within first week of update
- 50%+ of users share at least one meal
- Diet score feature used in 80%+ of analyses

## Open Questions

1. **Password Reset:** Should we implement password reset via email in this iteration, or defer to future release?
   - **Decision:** Defer to future release (not in scope)

2. **Social Media SDKs:** Should we integrate official social media SDKs or rely on iOS native sharing?
   - **Decision:** Start with iOS native sharing (UIActivityViewController), add SDKs if user feedback demands

3. **Data Migration:** Should we migrate existing meals to a "legacy" user or leave them orphaned?
   - **Decision:** Leave nullable for now, add migration tool in future if needed

4. **Custom Diet:** How much flexibility should "Custom" diet preference offer?
   - **Decision:** Custom allows manual macro targets (e.g., 40% protein, 30% carbs, 30% fat)

5. **Shareable Link Hosting:** Where should public shared meal pages be hosted?
   - **Decision:** Backend serves JSON via `/api/share/{token}`, simple web view future enhancement

6. **Connection Pool Size:** What are the optimal min/max connection pool settings for expected load?
   - **Decision:** Start with min=5, max=20, monitor and adjust based on production metrics

7. **Token Refresh:** Should we implement automatic token refresh or require re-login after 30 days?
   - **Decision:** Require re-login for security, add refresh token in future iteration if needed

8. **Diet Scoring Algorithm:** Should scoring be purely macro-based or include food quality (processed vs. whole foods)?
   - **Decision:** Start with macro-based scoring, add food quality scoring in future iteration

9. **App Icon Design:** Should we hire a designer or use AI-generated icon?
   - **Decision:** Use AI-generated icon (DALL-E, Midjourney) with refinement, option to hire designer later

10. **Weight Units:** Should we auto-detect user's region for kg/lbs default or let them choose?
    - **Decision:** Let users choose in profile, default to kg (international standard)

---

## Implementation Order

1. **US-001** - Database schema (foundation for all features)
2. **US-002, US-003** - Backend authentication (register, login)
3. **US-004** - Authentication middleware
4. **US-005, US-006** - iOS auth screens (register, login)
5. **US-021** - Session management and auto-login
6. **US-007** - iOS home page
7. **US-008** - App icon and tile
8. **US-009** - User profile and diet preferences
9. **US-010, US-011** - Diet scoring (backend + iOS)
10. **US-012** - Tag meals as consumed
11. **US-013** - Edit consumed meals
12. **US-014, US-015** - Weight and ketone tracking
13. **US-016** - Eating trends dashboard
14. **US-017, US-018, US-019** - Sharing features
15. **US-020** - Backend concurrency improvements

This order minimizes integration risk by establishing authentication first, then building user-specific features, and finally adding analytics and sharing.

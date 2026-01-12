# PRD: AI-Powered Nutrition Analyzer Mobile App

## Introduction

A mobile iOS application that enables users to instantly analyze the nutritional content of their meals through photo capture. Users simply take a picture of their food, and the app leverages Google's Gemini AI to identify the food items and calculate comprehensive nutritional information including macronutrients (protein, carbohydrates, fats) and other key dietary metrics.

**Problem Statement:** Tracking nutrition manually is time-consuming and error-prone. Users need a quick, accurate way to understand what they're eating without manual data entry or food database searches.

## Goals

- Enable users to capture and analyze food nutrition in under 10 seconds
- Provide accurate macronutrient breakdowns (protein, carbs, fats) within ±15% margin
- Deliver a native iOS experience with smooth camera integration
- Create an intuitive, single-tap workflow from photo to nutrition data
- Build a scalable foundation for future Android expansion

## Technology Stack

### Mobile (iOS)
- **Platform:** iOS 16.0+
- **Language:** Swift 5.9+
- **Framework:** SwiftUI
- **Camera:** AVFoundation
- **Image Processing:** CoreImage + Vision Framework
- **Networking:** URLSession with async/await
- **State Management:** SwiftUI @StateObject + @Observable
- **Dependency Management:** Swift Package Manager

### Backend/AI
- **AI Service:** Google Gemini Pro Vision API
- **Backend:** Node.js 20 LTS + TypeScript
- **Framework:** Fastify (lightweight API gateway)
- **Database:** PostgreSQL 15 + Prisma ORM (for user history, analytics)
- **Image Storage:** AWS S3 or Cloudflare R2
- **API Authentication:** JWT tokens

### Deployment
- **Mobile:** Apple App Store (TestFlight for beta)
- **Backend:** Docker containers on AWS ECS / Railway
- **Database:** Managed PostgreSQL (AWS RDS / Supabase)
- **CDN:** CloudFront / Cloudflare for image delivery

**Rationale:** Swift/SwiftUI provides the best native iOS experience with excellent camera integration. Gemini Pro Vision is specifically designed for image understanding and can identify multiple food items with nutritional reasoning. Node.js backend serves as a lightweight proxy to manage API keys securely and log usage. PostgreSQL enables future features like meal history and trend analysis.

## Project Structure

### iOS App Structure
```
NutritionAI/
├── NutritionAI/
│   ├── App/
│   │   └── NutritionAIApp.swift         # App entry point
│   ├── Views/
│   │   ├── CameraView.swift             # Camera capture UI
│   │   ├── NutritionResultView.swift    # Results display
│   │   ├── HistoryView.swift            # Past meals
│   │   └── Components/                  # Reusable UI components
│   ├── ViewModels/
│   │   ├── CameraViewModel.swift
│   │   └── NutritionViewModel.swift
│   ├── Models/
│   │   ├── NutritionData.swift          # Data models
│   │   └── MealRecord.swift
│   ├── Services/
│   │   ├── CameraService.swift          # Camera handling
│   │   ├── APIService.swift             # Backend communication
│   │   └── StorageService.swift         # Local persistence
│   └── Resources/
│       └── Assets.xcassets
├── NutritionAITests/
└── NutritionAI.xcodeproj
```

### Backend Structure
```
nutrition-api/
├── src/
│   ├── routes/
│   │   └── analyze.ts           # POST /analyze endpoint
│   ├── services/
│   │   ├── gemini.ts            # Gemini API integration
│   │   └── storage.ts           # S3/R2 image storage
│   ├── schemas/
│   │   └── nutrition.ts         # Zod validation schemas
│   └── index.ts                 # Server entry
├── prisma/
│   └── schema.prisma            # Database schema
├── tests/
└── package.json
```

## User Stories

### US-001: iOS Project Setup
**Description:** As a developer, I need the iOS project scaffolded with SwiftUI and required dependencies.

**Acceptance Criteria:**
- [ ] Create new iOS project in Xcode with SwiftUI
- [ ] Set minimum iOS deployment target to 16.0
- [ ] Configure App capabilities (Camera access)
- [ ] Add Info.plist entries for camera usage description
- [ ] Set up basic SwiftUI navigation structure
- [ ] Project builds successfully
- [ ] No compiler warnings

### US-002: Backend API Setup
**Description:** As a developer, I need the backend API initialized with Fastify and Gemini integration.

**Acceptance Criteria:**
- [ ] Initialize Node.js project with TypeScript
- [ ] Install Fastify, @google/generative-ai, Zod, Prisma
- [ ] Configure environment variables for Gemini API key
- [ ] Create basic server with health check endpoint
- [ ] Set up CORS for mobile app requests
- [ ] Server starts on configurable port
- [ ] Typecheck passes

### US-003: Database Schema Setup
**Description:** As a developer, I need the database schema for storing meal analysis history.

**Acceptance Criteria:**
- [ ] Install and initialize Prisma
- [ ] Create schema with MealAnalysis model (id, userId, imageUrl, nutritionData, timestamp)
- [ ] Add NutritionData JSON schema (calories, protein, carbs, fat, servingSize)
- [ ] Generate Prisma client
- [ ] Run initial migration
- [ ] Typecheck passes

### US-004: Camera Capture
**Description:** As a user, I want to take a picture of my food using the device camera.

**Acceptance Criteria:**
- [ ] Camera view displays on app launch or navigation
- [ ] User can see live camera preview
- [ ] Capture button triggers photo capture
- [ ] Camera permission request shown if not granted
- [ ] Captured image displayed in preview
- [ ] Option to retake or confirm photo
- [ ] Image compressed to reasonable size (< 2MB)
- [ ] No memory leaks in camera session

### US-005: Gemini Integration Endpoint
**Description:** As a backend developer, I need an endpoint that sends images to Gemini for nutrition analysis.

**Acceptance Criteria:**
- [ ] POST /api/analyze accepts base64 or multipart image
- [ ] Image validated (format: JPG/PNG, size < 5MB)
- [ ] Gemini Pro Vision API called with optimized prompt
- [ ] Prompt requests: food identification, portion estimation, macro breakdown
- [ ] Response parsed and structured as JSON
- [ ] Error handling for API failures (retry logic)
- [ ] Returns 200 with nutrition data or 4xx/5xx with error details
- [ ] Typecheck passes
- [ ] Tests pass

### US-006: Display Nutrition Results
**Description:** As a user, I want to see the nutritional breakdown of my food immediately after capture.

**Acceptance Criteria:**
- [ ] Loading indicator shown during API call
- [ ] Nutrition results displayed in clear, readable format
- [ ] Shows: total calories, protein (g), carbs (g), fat (g)
- [ ] Displays identified food items as list
- [ ] Shows estimated portion/serving size
- [ ] Error message shown if analysis fails
- [ ] User can dismiss and return to camera
- [ ] Smooth transition animation

### US-007: API Communication Layer
**Description:** As a developer, I need a service to handle API requests from the iOS app.

**Acceptance Criteria:**
- [ ] APIService struct with async/await methods
- [ ] analyzeImage() method sends image to backend
- [ ] Proper error handling and typing
- [ ] Network reachability check
- [ ] Timeout handling (30 second max)
- [ ] Decodable response models
- [ ] Unit tests for happy path and error cases
- [ ] No compiler warnings

### US-008: Save Analysis History
**Description:** As a user, I want my analyzed meals saved so I can review them later.

**Acceptance Criteria:**
- [ ] Successful analyses saved to local Core Data/SwiftData
- [ ] Backend stores analysis with timestamp in PostgreSQL
- [ ] Each record includes: image thumbnail, nutrition data, date/time
- [ ] History persists across app restarts
- [ ] Maximum 100 local entries (auto-prune oldest)
- [ ] Tests verify storage and retrieval

### US-009: History View
**Description:** As a user, I want to view a list of my previously analyzed meals.

**Acceptance Criteria:**
- [ ] History accessible via tab or navigation
- [ ] List shows meals in reverse chronological order
- [ ] Each item displays: thumbnail, total calories, date
- [ ] Tapping item shows full nutrition details
- [ ] Empty state shown when no history
- [ ] Pull-to-refresh updates from backend
- [ ] Smooth scrolling performance

### US-010: Nutrition Data Model
**Description:** As a developer, I need structured models for nutrition data.

**Acceptance Criteria:**
- [ ] NutritionData struct with: calories, protein, carbs, fat, fiber, sugar
- [ ] FoodItem model with: name, portion, confidence score
- [ ] MealAnalysis model combining image, foods, nutrition, timestamp
- [ ] All models Codable for JSON serialization
- [ ] Computed properties for macro percentages
- [ ] Unit tests for model logic
- [ ] No compiler warnings

### US-011: Error Handling & Edge Cases
**Description:** As a user, I want clear feedback when things go wrong.

**Acceptance Criteria:**
- [ ] Camera permission denied: show alert with settings link
- [ ] No internet: show offline message
- [ ] API timeout: show retry option
- [ ] Invalid image (no food detected): friendly message
- [ ] Backend error: generic error message (don't expose internals)
- [ ] All errors logged for debugging
- [ ] App doesn't crash on any error scenario

### US-012: Gemini Prompt Engineering
**Description:** As a developer, I need an optimized prompt for accurate nutrition extraction.

**Acceptance Criteria:**
- [ ] Prompt instructs Gemini to identify all visible food items
- [ ] Requests portion size estimation
- [ ] Asks for macro breakdown per item and total
- [ ] Specifies JSON output format
- [ ] Includes confidence scoring
- [ ] Tested with 10+ sample food images
- [ ] Average accuracy validated against known nutritional data
- [ ] Documentation of prompt template

## Functional Requirements

**Core Functionality:**
- FR-1: App must request and handle camera permissions appropriately
- FR-2: Camera must capture images at sufficient resolution for AI analysis (min 1080p)
- FR-3: Images must be compressed before upload (target: 1-2MB)
- FR-4: API must respond within 10 seconds for 95% of requests
- FR-5: Nutrition data must include: calories, protein (g), carbs (g), fat (g)
- FR-6: App must work in both portrait and landscape orientations
- FR-7: All text must be readable with iOS Dynamic Type settings
- FR-8: App must support iOS Dark Mode

**Data Requirements:**
- FR-9: Nutrition values rounded to 1 decimal place
- FR-10: Food items listed with individual and combined totals
- FR-11: Portion sizes displayed in common units (cups, oz, grams)
- FR-12: Timestamps stored in UTC, displayed in user's timezone

**Quality Requirements:**
- FR-13: App must handle low-light images gracefully
- FR-14: Multiple food items in one image must be separately identified
- FR-15: API must return structured JSON with consistent schema
- FR-16: Backend must rate-limit requests to prevent abuse (100 req/hour per user)

## Non-Goals (Out of Scope for v1)

- ❌ Android version (iOS only for v1)
- ❌ User accounts and authentication (local storage only)
- ❌ Social features (sharing, comparing with friends)
- ❌ Barcode scanning
- ❌ Manual food entry or database search
- ❌ Meal planning or recommendations
- ❌ Integration with health apps (Apple Health, MyFitnessPal)
- ❌ Custom dietary goals or tracking over time
- ❌ Offline AI processing (requires cloud API)
- ❌ Video analysis or multiple photos per meal
- ❌ Recipe generation or cooking instructions
- ❌ Restaurant menu integration
- ❌ Micronutrient analysis (vitamins, minerals) - macros only

## Technical Considerations

**Performance:**
- Target: Camera to results in under 10 seconds
- Image compression must not degrade AI accuracy
- UI must remain responsive during API calls
- Local database queries under 100ms

**Security:**
- API keys never embedded in iOS app binary
- Backend validates all image uploads
- Rate limiting to prevent API abuse
- Images automatically deleted after 30 days
- No PII collected without user consent

**Scalability:**
- Backend stateless for horizontal scaling
- Database connection pooling configured
- Image storage uses CDN for global access
- Gemini API quota monitoring and alerts

**Testing Strategy:**
- Unit tests for ViewModels and Services (80% coverage target)
- UI tests for critical flows (camera → results)
- Integration tests for API endpoints
- Manual QA with diverse food images
- Beta testing via TestFlight with 20+ users

**AI Considerations:**
- Gemini prompt versioned and tested iteratively
- Fallback handling if Gemini returns unexpected format
- Confidence scores evaluated (reject if < 50%)
- Edge cases: empty plates, unclear images, non-food items

## Success Metrics

**Functional Success:**
- ✅ 95% of food images return results within 10 seconds
- ✅ 80% user satisfaction with accuracy (beta survey)
- ✅ Zero crashes in production (Crashlytics monitoring)
- ✅ App Store approval on first submission

**Technical Success:**
- ✅ All unit tests pass
- ✅ No TypeScript/Swift compiler errors
- ✅ 80%+ code coverage on critical paths
- ✅ API P95 latency under 8 seconds

**User Experience:**
- ✅ Average time from app launch to results: < 15 seconds
- ✅ Users can complete full flow without documentation
- ✅ Accessibility score: A rating (Xcode Accessibility Inspector)

## Open Questions

1. **Gemini API Quota:** What's the expected daily usage? Need to estimate costs and set appropriate limits.
2. **Image Storage Duration:** Should we keep images for user history? Privacy implications?
3. **Portion Size Accuracy:** How confident can Gemini be without reference objects? Consider allowing users to input plate size?
4. **Multiple Foods:** Should we show per-item breakdowns or just totals in v1?
5. **Offline Mode:** Should we show cached history when offline?
6. **Subscription Model:** Will this be free in v1, or test monetization early?
7. **Data Export:** Should users be able to export their history (CSV, PDF)?
8. **Localization:** English-only for v1, or support multiple languages from start?

## Implementation Notes

**Phase 1: Foundation (Week 1-2)**
- US-001: iOS project setup
- US-002: Backend API setup
- US-003: Database schema

**Phase 2: Core Features (Week 3-4)**
- US-004: Camera capture
- US-005: Gemini integration
- US-012: Prompt engineering
- US-007: API communication

**Phase 3: UI & UX (Week 5-6)**
- US-006: Display results
- US-010: Data models
- US-011: Error handling

**Phase 4: History & Polish (Week 7-8)**
- US-008: Save history
- US-009: History view
- Beta testing and refinements

**Estimated Timeline:** 8 weeks to TestFlight beta

## Appendix: Example API Response

```json
{
  "success": true,
  "analysis": {
    "foods": [
      {
        "name": "Grilled Chicken Breast",
        "portion": "6 oz (170g)",
        "confidence": 0.92,
        "nutrition": {
          "calories": 280,
          "protein": 53.0,
          "carbs": 0.0,
          "fat": 6.0
        }
      },
      {
        "name": "Steamed Broccoli",
        "portion": "1 cup (91g)",
        "confidence": 0.88,
        "nutrition": {
          "calories": 31,
          "protein": 2.5,
          "carbs": 6.0,
          "fat": 0.3
        }
      }
    ],
    "totals": {
      "calories": 311,
      "protein": 55.5,
      "carbs": 6.0,
      "fat": 6.3
    },
    "timestamp": "2026-01-12T05:30:00Z"
  }
}
```

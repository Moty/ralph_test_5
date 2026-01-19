# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NutritionAI is an AI-powered nutrition analyzer consisting of an iOS app and a Node.js backend. Users photograph food to get nutritional analysis via Google Gemini AI.

## Repository Structure

- **NutritionAI/** - iOS Swift Package + Wrapper App (primary iOS project)
- **backend/** - Node.js/Fastify API server with TypeScript
- **NutritionAIApp/** - Deprecated standalone iOS project (do not use)

## Common Commands

### Backend

```bash
cd backend
npm install              # Install dependencies
npm run dev              # Start with hot reload (tsx watch)
npm run start            # Start production build (requires npm run build first)
npm run start:tsx        # Start without building (uses tsx)
npm run build            # Compile TypeScript
npm run typecheck        # Type check without building
npm test                 # Run tests (requires PostgreSQL test DB)
npm run deploy           # Deploy to Google Cloud Run
npx prisma generate      # Generate Prisma client
npx prisma migrate dev   # Run database migrations
```

### iOS App

```bash
cd NutritionAI
swift build              # Build Swift package
swift test               # Run package tests
open NutritionAIApp.xcodeproj  # Open in Xcode
```

In Xcode: ⌘⇧K to clean, ⌘R to build and run on physical iPhone (camera requires physical device).

## Architecture

### Backend (Fastify + TypeScript)

The backend uses a database abstraction layer (`src/services/database.ts`) supporting both PostgreSQL (via Prisma) and Firebase Firestore. Database type is auto-detected from environment variables.

**Key files:**
- `src/server.ts` - Entry point, registers routes and middleware
- `src/services/database.ts` - `DatabaseService` interface with `PostgresDatabase` and `FirestoreDatabase` implementations
- `src/services/gemini.ts` - Google Generative AI integration
- `src/services/auth.ts` - JWT token verification
- `src/routes/analyze.ts` - Image analysis endpoint (multipart upload → Gemini AI)
- `src/routes/auth.ts` - Register/login endpoints
- `src/routes/user.ts` - User statistics
- `src/routes/meals.ts` - Meal history CRUD

**Database selection:**
- Set `FIREBASE_PROJECT_ID` for Firestore
- Set `DATABASE_URL` for PostgreSQL
- `DATABASE_TYPE` env var can force selection

### iOS App (SwiftUI + Swift Package)

The app is structured as a Swift Package with a wrapper Xcode project for device deployment.

**Key components:**
- `Sources/NutritionAI/ContentView.swift` - Root view with tab navigation (Home, Camera, History, Settings)
- `Services/AuthService.swift` - JWT token management with Keychain storage
- `Services/APIService.swift` - Backend communication (async/await, multipart upload)
- `Services/StorageService.swift` - Core Data for local meal history
- `Services/SyncService.swift` - Cloud sync between local and server data
- `Views/CameraView.swift` - AVFoundation camera capture with preview/confirm workflow
- `Views/NutritionResultView.swift` - Displays analysis results with confidence scores

**Configuration:**
- `Package.swift` defines `TESTING` compile flag for macOS/test builds to exclude `@main`
- `Info.plist` contains camera permission (`NSCameraUsageDescription`)
- Backend URL configurable in Settings view (default: 192.168.50.48:3000)

## Environment Variables (Backend)

Required:
- `GEMINI_API_KEY` - Google Generative AI key
- `JWT_SECRET` - Secret for JWT signing

Database (one of):
- `FIREBASE_PROJECT_ID` - For Firestore
- `DATABASE_URL` - PostgreSQL connection string (e.g., `postgresql://user:pass@localhost:5432/nutritionai`)

Optional:
- `PORT` - Server port (default: 8080)
- `DATABASE_TYPE` - Force `firestore` or `postgres`

## API Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | /health | Health check | No |
| POST | /api/auth/register | Create account | No |
| POST | /api/auth/login | Login | No |
| GET | /api/user/stats | User meal statistics | Yes |
| POST | /api/analyze | Analyze food image (multipart) | Optional* |
| GET | /api/meals | Get user's meal history | Yes |
| GET | /api/meals/:id | Get single meal by ID | Yes |

*Optional auth: Works for both authenticated users and guests. Authenticated requests save meals to history.

## Testing

**Backend tests** use Node.js built-in test runner:
```bash
npm test  # Runs src/__tests__/*.test.ts
```

**iOS tests** run via Swift Package Manager or Xcode:
```bash
swift test  # Runs Tests/NutritionAITests/
```

## Key Patterns

- Backend uses singleton pattern for database connection (`getDb()`)
- iOS uses `@Published` properties in service classes for SwiftUI reactivity
- All API responses follow consistent JSON structure with `foods[]` array and `totals` object
- Image uploads limited to 5MB, compressed on iOS before sending
- Rate limiting: 100 requests/hour per IP

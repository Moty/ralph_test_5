# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NutritionAI is an AI-powered nutrition analyzer with iOS, web, and Node.js backend components. Users photograph food to get nutritional analysis via Google Gemini AI.

## Repository Structure

- **web/** - React + Vite + TypeScript web application (Firebase Hosting)
- **NutritionAI/** - iOS Swift Package + Wrapper App (primary iOS project)
- **backend/** - Node.js/Fastify API server with TypeScript (Firestore database)
- **NutritionAIApp/** - Deprecated standalone iOS project (do not use)

## Production Environment

| Component | URL |
|-----------|-----|
| Web App | https://nutritionai2026.web.app |
| Backend | https://nutrition-ai-backend-1051629517898.us-central1.run.app |

Verify backend health:
```bash
curl -s https://nutrition-ai-backend-1051629517898.us-central1.run.app/health
```

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
npm test                 # Run tests
npm run deploy           # Deploy to Google Cloud Run
```

### Web App

```bash
cd web
npm install              # Install dependencies
npm run dev              # Start dev server (http://localhost:5173)
npm run build            # Type check + production build
npm run lint             # Run ESLint
npm test                 # Run tests with Vitest
npm run test:ui          # Run tests with UI
npm run preview          # Preview production build
```

Deploy to Firebase Hosting:
```bash
cd web && npm run build && cd .. && firebase deploy --only hosting
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

The backend uses Firebase Firestore for data storage.

**Key files:**
- `src/server.ts` - Entry point, registers routes and middleware
- `src/services/database.ts` - Firestore database service
- `src/services/firebase.ts` - Firebase Admin SDK initialization
- `src/services/gemini.ts` - Google Generative AI integration
- `src/services/auth.ts` - JWT token verification
- `src/routes/analyze.ts` - Image analysis endpoint (multipart upload → Gemini AI)
- `src/routes/auth.ts` - Register/login endpoints
- `src/routes/user.ts` - User statistics
- `src/routes/meals.ts` - Meal history CRUD

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

### Web App (React + Vite)

React 19 SPA with React Router for navigation and context-based auth state.

**Key components:**
- `src/App.tsx` - Main routing with protected routes, 401 auto-logout handler
- `src/contexts/AuthContext.tsx` - Auth state management (JWT in localStorage, guest mode)
- `src/services/api.ts` - API client with typed endpoints (`authApi`, `userApi`, `mealApi`)
- `src/pages/` - Route components: Home, Camera, Analyze, History, MealDetail, Settings, Login

**Configuration:**
- `VITE_API_BASE_URL` env var for backend URL (default: localhost:3001)
- `VITE_SHOW_API_OVERRIDE` to show API URL override in Settings (dev only)

## Environment Variables

### Backend

Required:
- `GEMINI_API_KEY` - Google Generative AI key
- `JWT_SECRET` - Secret for JWT signing
- `FIREBASE_PROJECT_ID` - Firebase project ID for Firestore

Optional:
- `PORT` - Server port (default: 8080)
- `FIREBASE_SERVICE_ACCOUNT` - Service account JSON (for local development)

### Web App

- `VITE_API_BASE_URL` - Backend URL (default: http://localhost:3001)
- `VITE_SHOW_API_OVERRIDE` - Show API URL override in Settings (dev only)

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
cd backend && npm test  # Runs src/__tests__/*.test.ts
```

**Web tests** use Vitest with React Testing Library:
```bash
cd web && npm test              # Run all tests
cd web && npm test -- --run     # Run once without watch
cd web && npm run test:ui       # Interactive test UI
```

**iOS tests** run via Swift Package Manager or Xcode:
```bash
cd NutritionAI && swift test  # Runs Tests/NutritionAITests/
```

## Key Patterns

- Backend uses singleton pattern for database connection (`getDb()`)
- iOS uses `@Published` properties in service classes for SwiftUI reactivity
- Web uses React Context for auth state with auto-logout on 401 responses
- All API responses follow consistent JSON structure with `foods[]` array and `totals` object
- Image uploads limited to 5MB, compressed on iOS before sending
- Rate limiting: 100 requests/hour per IP

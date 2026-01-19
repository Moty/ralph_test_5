# NutritionAI

AI-Powered Nutrition Analyzer Mobile App - iOS app with photo-based food nutrition analysis

## Quick Start - Running the iOS App

### Step-by-Step Build Instructions

#### 1. Start the Backend Server

```bash
cd /Users/moty/Projects/experiments/ralph_test_5/backend
npm install
npm run dev
```

The server will start on port 3000 and show available IP addresses.

#### 2. Open the Correct Xcode Project

**IMPORTANT**: There are two Xcode projects. Open the one inside `NutritionAI/`:

```bash
open /Users/moty/Projects/experiments/ralph_test_5/NutritionAI/NutritionAIApp.xcodeproj
```

⚠️ Do NOT open `/Users/moty/Projects/experiments/ralph_test_5/NutritionAIApp/` - that's the old project!

#### 3. Configure Backend URL and Create Account

The app defaults to `192.168.50.48:3000`. If your Mac's IP is different:

1. Find your Mac's IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
2. Run the app on your iPhone
3. **Register a new account** on the registration screen
4. If needed, go to **Settings** tab to update backend URL
5. Enter your backend URL (e.g., `http://YOUR_IP:3000`)
6. Tap **Save URL**

#### 4. Build and Run

1. In Xcode, select your iPhone as the target device
2. Clean build folder: **Product → Clean Build Folder** (⌘⇧K)
3. Build and run: **Product → Run** (⌘R)
4. Grant camera and local network permissions when prompted

#### 5. Test the App

1. **Register/Login**: Create an account or login
2. **Home Tab**: View your meal statistics and quick capture tiles
3. **Camera Tab**: Take a photo of food
4. **Confirm**: Tap confirm to analyze
5. **Results**: View nutrition breakdown (calories, protein, carbs, fat)
6. **History Tab**: View previously analyzed meals
7. **Settings Tab**: Change AI model, backend URL, or logout

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Shows "Hello World" or old UI | You opened the wrong project. Open `NutritionAI/NutritionAIApp.xcodeproj` |
| "No such module NutritionAI" | Select the NutritionAIApp target, add package to Frameworks |
| Camera not working | Only works on physical iPhone, not simulator |
| Network error | Check backend is running and URL is correct in Settings |
| Quota exceeded | Switch to a different AI model in Settings |

---

## Project Structure

- **NutritionAI/** - iOS Swift Package + Wrapper App (USE THIS)
  - `Sources/NutritionAI/` - Main package source code
  - `NutritionAIApp/` - Wrapper Xcode app project
  - `NutritionAIApp.xcodeproj` - Open this project!
- **NutritionAIApp/** - Old standalone project (DEPRECATED - do not use)
- **backend/** - Node.js/Fastify API server for nutrition analysis
- **web/** - React + Vite + TypeScript web application

## iOS App

### Requirements
- iOS 16.0 or later
- macOS 12.0 or later (for development)
- Swift 5.9+

### Setup
```bash
cd NutritionAI
swift build
```

### Features
- SwiftUI-based iOS application
- **User Authentication**
  - Register new account with email, name, and password
  - Login with email and password
  - JWT token stored securely in iOS Keychain
  - Auto-login on app launch if valid token exists
  - Logout functionality with confirmation dialog
- **Home Dashboard**
  - Personalized welcome message with user's name
  - Meal statistics for today, this week, and all time
  - Quick capture tiles for Full Meal, Snack, and Quick Add
  - Pull-to-refresh to update stats
  - Empty state for new users
- **Tab Navigation** between Home, Camera, History, and Settings
  - Clear tab icons representing each function
  - Smooth transitions between tabs
  - Tab selection persists when switching
  - Camera resets when navigating away and back
- **History View** for viewing previously analyzed meals
  - Displays meals in reverse chronological order (most recent first)
  - Each item shows thumbnail placeholder, total calories, date/time, item count
  - Tapping item opens full nutrition details in sheet
  - Empty state message when no history exists
  - Smooth scrolling with LazyVStack for performance
  - Error handling for storage failures
  - **Dark Mode support** with adaptive colors
- **Camera capture** with AVFoundation for taking food photos
  - Real-time camera preview
  - Capture button with retake/confirm workflow
  - Automatic image compression to under 2MB
  - **Camera permission handling** with clear user guidance
    - Alert shown when camera access is denied
    - Direct link to Settings app for permission management
    - Permission status display in camera view
    - Graceful handling of permission requests on first launch
    - No app crashes when permission denied
- **Nutrition Results View** displaying analysis results
  - Total nutrition summary with calories, protein, carbs, and fat
  - Individual food items with portion sizes
  - Confidence scoring with color-coded badges
  - Loading indicator during API calls
  - Error handling with user-friendly messages
  - Dismiss button to return to camera
  - **Dark Mode support** with adaptive colors for light/dark themes
- **Local Storage** with Core Data for meal history
  - Automatic saving of successful analyses
  - Stores nutrition data with optional thumbnail images
  - Auto-prune to maintain maximum 100 entries (keeps most recent)
  - Data persists across app restarts
  - Fetch methods for retrieving complete or recent history
- **API Service** for backend communication
  - Async/await URLSession-based networking
  - Multipart/form-data image upload
  - Automatic JSON decoding to MealAnalysis models
  - **Network error handling** with user-friendly messages
    - Offline detection (no internet connection)
    - Timeout handling with retry option
    - User-friendly error messages that don't expose internal details
    - Server error sanitization (hides Gemini/API internal errors)
  - 30-second request timeout
- Basic navigation structure
- Structured data models for nutrition information:
  - **NutritionData**: Calories, protein, carbs, fat with macro percentages
  - **FoodItem**: Food name, portion size, nutrition data, confidence score
  - **MealAnalysis**: Complete meal analysis with multiple foods and totals

### Configuration
Camera permissions are configured in `Info.plist` with `NSCameraUsageDescription`.

## Backend API

### Requirements
- Node.js 18+ 
- npm or yarn

### Setup
```bash
cd backend
npm install
```

### Environment Variables
Create a `.env` file in the backend directory:
```
PORT=3000
DATABASE_URL=postgresql://user:password@localhost:5432/nutritionai
GEMINI_API_KEY=your_gemini_api_key_here
JWT_SECRET=your_jwt_secret_key_here
```

### Database Schema
The backend uses Prisma with PostgreSQL. The schema includes:
- **User**: User accounts with email, password hash, and name
- **MealAnalysis**: Nutrition analysis records linked to users

### Database Setup
```bash
# Generate Prisma client
npx prisma generate

# Run migrations (requires PostgreSQL running)
npx prisma migrate dev
```

### Development
```bash
npm run dev     # Start with hot reload
npm start       # Start server
npm run typecheck  # Run TypeScript checks
npm test        # Run tests
```

### API Endpoints

| Method | Path | Description | Auth Required |
|--------|------|-------------|---------------|
| GET | /health | Health check endpoint | No |
| POST | /api/auth/register | Register new user account | No |
| POST | /api/auth/login | Login with email and password | No |
| GET | /api/user/stats | Get user meal statistics | Yes |
| POST | /api/analyze | Analyze food image and return nutrition data | Yes |

#### POST /api/auth/register
Create a new user account.

**Request:**
- Content-Type: `application/json`
- Body:
```json
{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe"
}
```

**Response (201 Created):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "cm5abc123xyz",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Error Responses:**
- 400: Invalid email format, weak password, or email already exists

#### POST /api/auth/login
Login with email and password.

**Request:**
- Content-Type: `application/json`
- Body:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "cm5abc123xyz",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Error Responses:**
- 401: Invalid email or password

#### GET /api/user/stats
Get meal statistics for the authenticated user.

**Request:**
- Headers: `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "today": {
    "count": 2,
    "avgCalories": 450,
    "totalCalories": 900,
    "totalProtein": 60,
    "totalCarbs": 80,
    "totalFat": 30
  },
  "week": {
    "count": 15,
    "avgCalories": 500,
    "totalCalories": 7500,
    "totalProtein": 450,
    "totalCarbs": 900,
    "totalFat": 300
  },
  "allTime": {
    "count": 50,
    "avgCalories": 520,
    "totalCalories": 26000,
    "totalProtein": 1500,
    "totalCarbs": 3000,
    "totalFat": 1000
  }
}
```

**Error Responses:**
- 401: Missing or invalid authentication token

#### POST /api/analyze
Analyze food image and return nutrition data (requires authentication).

**Request:**
- Headers: `Authorization: Bearer <token>`
- Content-Type: `multipart/form-data`
- Body: Image file (JPG/PNG, max 5MB)

**Response (200 OK):**
```json
{
  "id": "cm5abc123xyz",
  "foods": [
    {
      "name": "Grilled Chicken Breast",
      "portion": "6 oz",
      "nutrition": {
        "calories": 280,
        "protein": 53,
        "carbs": 0,
        "fat": 6
      },
      "confidence": 0.95
    }
  ],
  "totals": {
    "calories": 280,
    "protein": 53,
    "carbs": 0,
    "fat": 6
  }
}
```

**Error Responses:**
- 400: Invalid file format or size
- 408: Request timeout (>30 seconds)
- 500: Analysis failed

### Features
- TypeScript with ES modules
- Fastify web framework
- CORS enabled for mobile app requests
- Multipart file upload support
- Environment-based configuration
- **User Authentication**
  - JWT-based authentication with 30-day token expiry
  - bcrypt password hashing
  - Register and login endpoints
  - Auth middleware for protected routes
- **User Management**
  - User profiles with email, name, and password
  - User statistics endpoint for dashboard
  - Meal analyses linked to user accounts
- Prisma ORM with PostgreSQL database
- MealAnalysis model for storing nutrition data
- **Database persistence** for meal analyses
  - Saves analysis results to PostgreSQL via Prisma
  - Stores userId, imageUrl, nutritionData JSON, timestamp
  - Returns analysis ID in API response
  - Graceful error handling (analysis returned even if save fails)
- **Gemini AI integration** for nutrition analysis
  - Google Generative AI SDK (@google/generative-ai)
  - Environment variable validation on startup
  - Error handling for API initialization
- **Image analysis endpoint** at POST /api/analyze
  - Accepts JPG/PNG images up to 5MB
  - Validates file format and size
  - 30-second timeout handling
  - Structured JSON response with nutrition data
  - Confidence scoring for food identification
- **Rate limiting** to prevent API abuse
  - 100 requests per hour per IP address
  - 429 status code when limit exceeded
  - Retry-After header in rate limit responses
  - Rate limit headers (x-ratelimit-limit, x-ratelimit-remaining, x-ratelimit-reset)

## Web App

### Requirements
- Node.js 18+
- npm or yarn

### Setup
```bash
cd web
npm install
```

### Environment Variables
Create a `.env` file in the web directory:
```
VITE_API_BASE_URL=http://localhost:3000
```

### Development
```bash
npm run dev     # Start dev server on http://localhost:5173
npm run build   # Build for production
npm run preview # Preview production build
```

### Features
- React + Vite + TypeScript web application
- **Routing** with react-router-dom
  - Home - Dashboard placeholder
  - Camera - Camera capture placeholder
  - History - Meal history placeholder
  - Settings - Settings placeholder
  - Login - Login/Register placeholder
- Environment-based backend API configuration

## Development

The app is organized as a Swift Package with iOS 16 as the minimum deployment target.

### Build
```bash
cd NutritionAI
swift build
```

### Project Files
- `Sources/NutritionAI/NutritionAIApp.swift` - Main app entry point
- `Sources/NutritionAI/ContentView.swift` - Root view
- `Sources/NutritionAI/Views/CameraView.swift` - Camera capture interface with photo preview and API integration
- `Sources/NutritionAI/Views/NutritionResultView.swift` - Nutrition results display with loading and error states
- `Sources/NutritionAI/Views/HistoryView.swift` - Meal history list with navigation to details
- `Sources/NutritionAI/Views/HomeView.swift` - Home dashboard with stats and quick capture
- `Sources/NutritionAI/Views/LoginView.swift` - Login screen with email and password
- `Sources/NutritionAI/Views/RegisterView.swift` - Registration screen for new users
- `Sources/NutritionAI/Views/StatsCard.swift` - Reusable stats card component
- `Sources/NutritionAI/Views/QuickCaptureTile.swift` - Quick capture tile component
- `Sources/NutritionAI/Services/APIService.swift` - Backend API communication service
- `Sources/NutritionAI/Services/AuthService.swift` - Authentication state management with Keychain storage
- `Sources/NutritionAI/Services/StorageService.swift` - Core Data storage for meal history
- `Sources/NutritionAI/Models/NutritionData.swift` - Nutrition data model with macro calculations
- `Sources/NutritionAI/Models/FoodItem.swift` - Food item model with nutrition data
- `Sources/NutritionAI/Models/MealAnalysis.swift` - Meal analysis model
- `Sources/NutritionAI/Models/User.swift` - User model
- `Sources/NutritionAI/Models/UserStats.swift` - User statistics model
- `Tests/NutritionAITests/APIServiceTests.swift` - Unit tests for API service
- `Info.plist` - Camera permissions and app configuration
- `Package.swift` - Swift package definition

## License

Proprietary

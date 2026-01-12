# NutritionAI

AI-Powered Nutrition Analyzer Mobile App - iOS app with photo-based food nutrition analysis

## Project Structure

- **NutritionAI/** - iOS SwiftUI application with camera-based food analysis
- **backend/** - Node.js/Fastify API server for nutrition analysis

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
- **History View** for viewing previously analyzed meals
  - Displays meals in reverse chronological order (most recent first)
  - Each item shows thumbnail placeholder, total calories, date/time, item count
  - Tapping item opens full nutrition details in sheet
  - Empty state message when no history exists
  - Smooth scrolling with LazyVStack for performance
  - Error handling for storage failures
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
```

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

| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Health check endpoint |
| POST | /api/analyze | Analyze food image and return nutrition data |

#### POST /api/analyze
Accepts a food image and returns detailed nutritional analysis. Analysis is saved to the database for history tracking.

**Request:**
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
- Prisma ORM with PostgreSQL database
- MealAnalysis model for storing nutrition data
- **Database persistence** for meal analyses
  - Saves analysis results to PostgreSQL via Prisma
  - Stores userId (placeholder), imageUrl, nutritionData JSON, timestamp
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
- `Sources/NutritionAI/Services/APIService.swift` - Backend API communication service
- `Sources/NutritionAI/Services/StorageService.swift` - Core Data storage for meal history
- `Sources/NutritionAI/Models/NutritionData.swift` - Nutrition data model with macro calculations
- `Sources/NutritionAI/Models/FoodItem.swift` - Food item model with nutrition data
- `Sources/NutritionAI/Models/MealAnalysis.swift` - Meal analysis model
- `Tests/NutritionAITests/APIServiceTests.swift` - Unit tests for API service
- `Info.plist` - Camera permissions and app configuration
- `Package.swift` - Swift package definition

## License

Proprietary

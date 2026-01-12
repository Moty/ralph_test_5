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
- **Camera capture** with AVFoundation for taking food photos
  - Real-time camera preview
  - Capture button with retake/confirm workflow
  - Automatic image compression to under 2MB
  - Camera permission handling
- Basic navigation structure
- Structured data models for nutrition information:
  - **NutritionData**: Calories, protein, carbs, fat with macro percentages
  - **FoodItem**: Food name, portion size, confidence score
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
Accepts a food image and returns detailed nutritional analysis.

**Request:**
- Content-Type: `multipart/form-data`
- Body: Image file (JPG/PNG, max 5MB)

**Response (200 OK):**
```json
{
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
- `Sources/NutritionAI/Views/CameraView.swift` - Camera capture interface with photo preview
- `Sources/NutritionAI/Models/NutritionData.swift` - Nutrition data model with macro calculations
- `Sources/NutritionAI/Models/FoodItem.swift` - Food item model
- `Sources/NutritionAI/Models/MealAnalysis.swift` - Meal analysis model
- `Info.plist` - Camera permissions and app configuration
- `Package.swift` - Swift package definition

## License

Proprietary

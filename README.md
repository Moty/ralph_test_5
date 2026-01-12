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
- Camera integration for food photo capture
- Basic navigation structure

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
```

### Development
```bash
npm run dev     # Start with hot reload
npm start       # Start server
npm run typecheck  # Run TypeScript checks
```

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Health check endpoint |

### Features
- TypeScript with ES modules
- Fastify web framework
- CORS enabled for mobile app requests
- Environment-based configuration

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
- `Info.plist` - Camera permissions and app configuration
- `Package.swift` - Swift package definition

## License

Proprietary

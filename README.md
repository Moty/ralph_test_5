# NutritionAI

AI-Powered Nutrition Analyzer Mobile App - iOS app with photo-based food nutrition analysis

## Project Structure

- **NutritionAI/** - iOS SwiftUI application with camera-based food analysis
- **backend/** - Node.js/Fastify API server with Gemini AI integration (coming soon)

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

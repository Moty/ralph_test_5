# NutritionAI Web App

Mobile-first React web application for NutritionAI - photo-based nutrition analysis.

## Quick Start

### Prerequisites
- Node.js 18+
- Backend server running on port 3000 (see `/backend`)

### Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

Open http://localhost:5173 in your browser.

### Environment Variables

Create a `.env` file:
```env
VITE_API_BASE_URL=http://localhost:3000
```

For production, create `.env.production`:
```env
VITE_API_BASE_URL=https://your-backend-url.com
VITE_SHOW_API_OVERRIDE=false
```

## Features

### Authentication
- **Login/Register**: Email and password authentication with JWT tokens
- **Guest Mode**: Local-only usage without account creation
- **Persistent Sessions**: Token stored in localStorage, auto-logout on 401

### Home Dashboard
- Today/Week/All Time nutrition statistics
- Quick capture buttons to jump to camera
- Loading and error states with retry
- Guest mode info card

### Camera Capture
- Live camera preview using getUserMedia API
- File upload fallback when camera unavailable
- Preview with retake/continue actions
- Automatic image compression

### Meal Analysis
- Submit photos to backend AI for nutrition analysis
- Loading indicator during analysis
- Results view with totals and individual food items
- Confidence scoring for each detected food

### Meal History
- Chronological list of past analyses
- Thumbnails with fallback icons
- Click to view full nutrition details
- Empty state for new users

### Settings
- System/Light/Dark theme toggle
- AI model selector (7 Gemini models)
- Logout functionality
- Backend URL override (development only)

## Testing

```bash
# Run tests
npm test

# Run tests with UI
npm test:ui
```

## Build for Production

```bash
# Build (runs typecheck + vite build)
npm run build

# Preview production build locally
npm run preview
```

The build output is in `dist/` directory.

## Deploy to Firebase Hosting

### First-time Setup

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

### Deploy

```bash
# Build the app
npm run build

# Deploy from project root
cd ..
firebase deploy --only hosting
```

Your app will be available at:
- https://nutritionai2026.web.app
- https://nutritionai2026.firebaseapp.com

See [../DEPLOYMENT.md](../DEPLOYMENT.md) for detailed deployment instructions.

## Project Structure

```
src/
├── components/     # Reusable UI components
│   └── ui/         # Button, Card, SectionHeader
├── contexts/       # React contexts (AuthContext)
├── pages/          # Route components
│   ├── Home.tsx
│   ├── Camera.tsx
│   ├── Analyze.tsx
│   ├── History.tsx
│   ├── MealDetail.tsx
│   ├── Settings.tsx
│   └── Login.tsx
├── services/       # API client
├── styles/         # CSS theme and base styles
├── test/           # Test utilities
├── App.tsx         # Main app with routing
└── main.tsx        # Entry point
```

## Tech Stack

- **React 19** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool and dev server
- **React Router 7** - Client-side routing
- **Vitest** - Testing framework
- **CSS Variables** - iOS-inspired theming

## Available Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run lint` | Run ESLint |
| `npm test` | Run tests |
| `npm run test:ui` | Run tests with UI |

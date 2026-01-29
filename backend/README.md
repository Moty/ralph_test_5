# Nutrition AI Backend

Fastify backend with AI-powered nutrition analysis using Google Gemini and Firebase Firestore.

## Quick Start

### Local Development

```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Edit .env with your credentials:
# GEMINI_API_KEY=your_key_here
# FIREBASE_PROJECT_ID=your-firebase-project
# JWT_SECRET=your_secret_here

# Start development server
npm run dev
```

## Project Structure

```
backend/
├── src/
│   ├── routes/          # API endpoints
│   │   ├── auth.ts      # User authentication
│   │   ├── user.ts      # User stats
│   │   ├── meals.ts     # Meal history
│   │   └── analyze.ts   # Image analysis
│   ├── services/        # Business logic
│   │   ├── database.ts  # Firestore database service
│   │   ├── firebase.ts  # Firebase setup
│   │   ├── gemini.ts    # Google Gemini AI
│   │   └── auth.ts      # JWT authentication
│   └── server.ts        # Entry point
└── Dockerfile           # Cloud Run deployment
```

## Environment Variables

```bash
# Required
GEMINI_API_KEY=your_gemini_api_key     # Get from https://makersuite.google.com/app/apikey
JWT_SECRET=your_random_secret          # Generate: openssl rand -base64 32
FIREBASE_PROJECT_ID=your-project-id    # Your Firebase project ID

# Optional
PORT=8080                              # Server port (default: 8080)
FIREBASE_SERVICE_ACCOUNT={"type":...}  # Service account JSON (for local dev)
```

## API Endpoints

### Authentication

**Register**
```http
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe"
}
```

**Login**
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

### Image Analysis

**Analyze Food Image**
```http
POST /api/analyze
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: multipart/form-data

image: [file]
model: "gemini-1.5-flash" (optional)
```

### User Data

**Get Nutrition Stats**
```http
GET /api/user/stats
Authorization: Bearer YOUR_JWT_TOKEN
```

## Deployment

### One-Time Setup

1. **Login to Google Cloud and Firebase:**
   ```bash
   gcloud auth login
   firebase login
   ```

2. **Set your project:**
   ```bash
   gcloud config set project nutritionai2026
   ```

3. **Enable required APIs:**
   ```bash
   gcloud services enable run.googleapis.com firestore.googleapis.com
   ```

### Deploy Backend (Cloud Run)

```bash
cd backend
npm run deploy
```

Or with environment variables (first time):
```bash
gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "FIREBASE_PROJECT_ID=nutritionai2026,GEMINI_API_KEY=YOUR_KEY,JWT_SECRET=YOUR_SECRET"
```

### Deploy Web App (Firebase Hosting)

```bash
cd web
npm run build
cd ..
firebase deploy --only hosting
```

### Deploy Both

From project root:
```bash
# Deploy backend
cd backend && npm run deploy && cd ..

# Deploy web
cd web && npm run build && cd .. && firebase deploy --only hosting
```

### Verify Deployment

```bash
# Check backend health
curl https://nutrition-ai-backend-1051629517898.us-central1.run.app/health

# Web app
open https://nutritionai2026.web.app
```

## Testing

```bash
# Run tests
npm test

# Type check
npm run typecheck
```

## Database Schema

### Firestore Collections

**users**
```typescript
{
  id: string,
  email: string,
  passwordHash: string,
  name: string,
  createdAt: Timestamp
}
```

**mealAnalyses**
```typescript
{
  id: string,
  userId: string | null,
  imageUrl: string,
  thumbnail: string | null,
  nutritionData: {
    foods: Array<{
      name: string,
      portion: string,
      nutrition: { calories, protein, carbs, fat },
      confidence: number
    }>,
    totals: { calories, protein, carbs, fat }
  },
  createdAt: Timestamp
}
```

## Scripts

```bash
npm run dev          # Start development server with hot reload
npm start            # Start production server
npm run build        # Compile TypeScript
npm run typecheck    # Type check without building
npm run deploy       # Deploy to Cloud Run
npm test             # Run tests
```

## Security

- Passwords hashed with bcrypt
- JWT tokens for authentication
- Rate limiting: 100 requests/hour
- File size limit: 5MB
- Input validation on all endpoints
- CORS enabled for iOS and web apps

## Features

- AI-powered nutrition analysis via Google Gemini
- Firebase Firestore database
- JWT authentication
- User registration and login
- Nutrition statistics (daily, weekly, all-time)
- Image upload and validation
- Rate limiting
- Cloud Run ready with auto-scaling
- Type-safe with TypeScript

## Additional Resources

- [Fastify Documentation](https://www.fastify.io/)
- [Google Gemini AI](https://ai.google.dev/)
- [Firebase Firestore](https://firebase.google.com/docs/firestore)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)

## Troubleshooting

**Firebase connection failed**
```bash
# Verify FIREBASE_PROJECT_ID is correct
# Check if Firestore is enabled in Firebase Console
# Ensure service account has correct permissions
```

**Gemini API errors**
```bash
# Verify your API key
curl https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_API_KEY

# Check quota: https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas
```

**Build errors**
```bash
# Clean install
rm -rf node_modules package-lock.json
npm install
```

## License

MIT

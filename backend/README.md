# Nutrition AI Backend

Fastify backend with AI-powered nutrition analysis using Google Gemini. Supports both **PostgreSQL** and **Firebase Firestore** databases.

## 🚀 Quick Start

### Local Development

```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Edit .env with your API keys
# GEMINI_API_KEY=your_key_here

# Choose your database:

# Option A: PostgreSQL (default)
export DATABASE_URL=postgresql://user:password@localhost:5432/nutritionai
npm run dev

# Option B: Firebase Firestore
export FIREBASE_PROJECT_ID=your-firebase-project
npm run dev
```

The server will automatically detect which database to use based on environment variables.

## 📁 Project Structure

```
backend/
├── src/
│   ├── routes/          # API endpoints
│   │   ├── auth.ts      # User authentication
│   │   ├── user.ts      # User stats
│   │   └── analyze.ts   # Image analysis
│   ├── services/        # Business logic
│   │   ├── database.ts  # Database abstraction layer
│   │   ├── firebase.ts  # Firebase/Firestore setup
│   │   ├── gemini.ts    # Google Gemini AI
│   │   └── auth.ts      # JWT authentication
│   ├── middleware/      # Request middleware
│   └── utils/          # Helper functions
├── prisma/             # PostgreSQL schema (optional)
└── Dockerfile          # Cloud Run deployment
```

## 🗄️ Database Support

The backend supports **two database options** with automatic detection:

### Firebase Firestore (Recommended)

**Pros:**
- ✅ No separate database setup
- ✅ Free tier: 1GB storage, 50K reads/day
- ✅ Auto-scales
- ✅ Perfect for Cloud Run

**Setup:**
```bash
export FIREBASE_PROJECT_ID=your-project-id
# Optional: FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}
npm run dev
```

See [FIREBASE_DEPLOYMENT.md](./FIREBASE_DEPLOYMENT.md) for details.

### PostgreSQL with Prisma

**Pros:**
- ✅ Relational database
- ✅ Complex queries
- ✅ Full SQL support

**Setup:**
```bash
export DATABASE_URL=postgresql://user:password@localhost:5432/nutritionai
npx prisma migrate dev
npm run dev
```

## 🔧 Environment Variables

```bash
# Required
GEMINI_API_KEY=your_gemini_api_key     # Get from https://makersuite.google.com/app/apikey
JWT_SECRET=your_random_secret          # Generate: openssl rand -base64 32

# Database - Choose ONE:
# Option A: Firestore
FIREBASE_PROJECT_ID=your-project-id

# Option B: PostgreSQL
DATABASE_URL=postgresql://user:password@localhost:5432/nutritionai

# Optional
PORT=8080                              # Server port (default: 8080)
DATABASE_TYPE=firestore                # Force database type (auto-detected if not set)
NODE_ENV=production                    # Environment mode
```

## 📡 API Endpoints

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

Returns daily, weekly, and all-time nutrition statistics.

## 🚀 Deployment

### Deploy to Google Cloud Run with Firestore

```bash
# 1. Enable Firestore in Firebase Console
# 2. Deploy
cd backend
gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars FIREBASE_PROJECT_ID=your-project,GEMINI_API_KEY=your_key,JWT_SECRET=$(openssl rand -base64 32)
```

See deployment guides:
- **[FIREBASE_DEPLOYMENT.md](./FIREBASE_DEPLOYMENT.md)** - Deploy with Firestore (recommended)
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Deploy with PostgreSQL
- **[QUICKSTART.md](./QUICKSTART.md)** - Quick comparison and setup

## 🧪 Testing

```bash
# Test database connection
./test-db.sh

# Run tests
npm test

# Type check
npm run typecheck
```

## 🔄 Database Migration

### Switch from PostgreSQL to Firestore

The backend includes a database abstraction layer that works with both databases seamlessly.

**Current setup (PostgreSQL):**
```typescript
// Uses Prisma automatically
const db = getDb(); // Returns PostgresDatabase
```

**Switch to Firestore:**
```bash
# Just set the environment variable
export FIREBASE_PROJECT_ID=your-project-id
# Remove or comment out DATABASE_URL
npm run dev
```

**Data migration:**
```bash
# Export PostgreSQL data
pg_dump -d nutritionai > backup.sql

# Use custom migration script (create as needed)
npm run migrate:firestore
```

## 📦 Database Schema

### Collections/Tables

**Users**
```typescript
{
  id: string,
  email: string,
  passwordHash: string,
  name: string,
  createdAt: Date
}
```

**MealAnalyses**
```typescript
{
  id: string,
  userId: string | null,
  imageUrl: string,
  nutritionData: {
    foods: Array<{
      name: string,
      portion: string,
      nutrition: {
        calories: number,
        protein: number,
        carbs: number,
        fat: number
      },
      confidence: number
    }>,
    totals: {
      calories: number,
      protein: number,
      carbs: number,
      fat: number
    }
  },
  createdAt: Date
}
```

## 🛠️ Development

```bash
# Install dependencies
npm install

# Run in development mode (auto-reload)
npm run dev

# Build TypeScript
npm run build

# Type check
npm run typecheck

# Test
npm test
```

## 📝 Scripts

```bash
npm run dev          # Start development server with hot reload
npm start            # Start production server
npm run build        # Compile TypeScript
npm run typecheck    # Type check without building
npm run deploy       # Deploy to Cloud Run
npm test            # Run tests
```

## 🔐 Security

- Passwords hashed with bcrypt
- JWT tokens for authentication
- Rate limiting: 100 requests/hour
- File size limit: 5MB
- Input validation on all endpoints
- CORS enabled for iOS app

## 🌟 Features

- ✅ AI-powered nutrition analysis via Google Gemini
- ✅ Dual database support (PostgreSQL + Firestore)
- ✅ JWT authentication
- ✅ User registration and login
- ✅ Nutrition statistics (daily, weekly, all-time)
- ✅ Image upload and validation
- ✅ Rate limiting
- ✅ Error handling and logging
- ✅ Cloud Run ready
- ✅ Auto-scaling
- ✅ Type-safe with TypeScript

## 📚 Additional Resources

- [Fastify Documentation](https://www.fastify.io/)
- [Google Gemini AI](https://ai.google.dev/)
- [Firebase Firestore](https://firebase.google.com/docs/firestore)
- [Prisma Documentation](https://www.prisma.io/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)

## 🐛 Troubleshooting

**Database connection failed**
```bash
# Test your database connection
./test-db.sh

# For Firestore: verify FIREBASE_PROJECT_ID is correct
# For PostgreSQL: check DATABASE_URL format and credentials
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

# Regenerate Prisma client (if using PostgreSQL)
npx prisma generate
```

## 📄 License

MIT

## 🤝 Contributing

Contributions welcome! Please open an issue or submit a pull request.

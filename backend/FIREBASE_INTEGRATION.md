# Firebase Integration Summary

## ✅ What Was Added

Your backend now supports **both PostgreSQL and Firebase Firestore** with automatic database detection!

### New Files

1. **[src/services/firebase.ts](src/services/firebase.ts)** - Firebase Admin SDK initialization
2. **[src/services/database.ts](src/services/database.ts)** - Database abstraction layer (works with both databases)
3. **[FIREBASE_DEPLOYMENT.md](FIREBASE_DEPLOYMENT.md)** - Complete Firebase deployment guide
4. **[test-db.sh](test-db.sh)** - Database connection test script
5. **[README.md](README.md)** - Comprehensive backend documentation

### Modified Files

1. **[src/server.ts](src/server.ts)** - Initialize Firebase on startup
2. **[src/routes/auth.ts](src/routes/auth.ts)** - Use database abstraction
3. **[src/routes/user.ts](src/routes/user.ts)** - Use database abstraction
4. **[src/routes/analyze.ts](src/routes/analyze.ts)** - Use database abstraction
5. **[Dockerfile](Dockerfile)** - Support both database types
6. **[.env.example](.env.example)** - Add Firebase configuration
7. **[QUICKSTART.md](QUICKSTART.md)** - Updated with Firestore option
8. **[package.json](package.json)** - Added firebase-admin dependency

## 🎯 How It Works

### Automatic Database Detection

The backend automatically chooses the right database:

```bash
# Firestore is used if:
export FIREBASE_PROJECT_ID=your-project-id

# PostgreSQL is used if:
export DATABASE_URL=postgresql://...

# Manual override:
export DATABASE_TYPE=firestore  # or 'postgres'
```

### Database Abstraction Layer

All database operations go through a unified interface:

```typescript
import { getDb } from './services/database.js';

const db = getDb(); // Auto-detects which database to use

// Same API for both databases:
await db.createUser({ email, passwordHash, name });
await db.findUserByEmail(email);
await db.createMealAnalysis({ userId, imageUrl, nutritionData });
await db.findMealAnalysesByUserId(userId);
```

### Firestore Collections

When using Firestore, data is stored in these collections:

```
📁 Firestore Database
├── users/
│   └── {userId}
│       ├── email
│       ├── passwordHash
│       ├── name
│       └── createdAt
└── mealAnalyses/
    └── {analysisId}
        ├── userId
        ├── imageUrl
        ├── nutritionData
        └── createdAt
```

## 🚀 Deployment Options

### Option A: Firebase/Firestore (Recommended)

**Why?**
- ✅ **Free tier**: 1GB storage, 50K reads/day, 20K writes/day
- ✅ **No database setup** - Firestore is built into Firebase
- ✅ **Auto-scaling** - Handles traffic spikes automatically
- ✅ **Serverless** - No database server to manage
- ✅ **Most small apps are FREE**

**Deploy:**
```bash
# 1. Create Firebase project
firebase login
firebase projects:create nutrition-ai

# 2. Enable Firestore (via console.firebase.google.com)

# 3. Deploy to Cloud Run
cd backend
gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars FIREBASE_PROJECT_ID=nutrition-ai,GEMINI_API_KEY=your_key,JWT_SECRET=$(openssl rand -base64 32)
```

### Option B: PostgreSQL (Cloud SQL)

**Why?**
- ✅ Relational database features
- ✅ Complex SQL queries
- ✅ Better for existing SQL apps

**Cost:** ~$7/month minimum

**Deploy:**
See [DEPLOYMENT.md](DEPLOYMENT.md)

## 📋 Environment Variables

### For Firestore Deployment

```bash
FIREBASE_PROJECT_ID=your-firebase-project-id   # Required
GEMINI_API_KEY=your_gemini_key                 # Required
JWT_SECRET=your_jwt_secret                     # Required
DATABASE_TYPE=firestore                        # Optional (auto-detected)
```

### For PostgreSQL Deployment

```bash
DATABASE_URL=postgresql://user:pass@host/db    # Required
GEMINI_API_KEY=your_gemini_key                 # Required
JWT_SECRET=your_jwt_secret                     # Required
DATABASE_TYPE=postgres                         # Optional (auto-detected)
```

## 🧪 Testing Locally

### Test with Firestore

```bash
# Set up Firebase credentials
export FIREBASE_PROJECT_ID=your-project-id
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
export GEMINI_API_KEY=your_key
export JWT_SECRET=test_secret

# Test connection
./test-db.sh

# Start server
npm run dev
```

### Test with PostgreSQL

```bash
# Set up PostgreSQL connection
export DATABASE_URL=postgresql://localhost/nutritionai
export GEMINI_API_KEY=your_key
export JWT_SECRET=test_secret

# Test connection
./test-db.sh

# Start server
npm run dev
```

## 🔄 Migration Between Databases

### Current Data in PostgreSQL? No Problem!

The abstraction layer makes it easy to switch:

**Step 1: Keep both databases in sync during transition**
```bash
# Use PostgreSQL in production
export DATABASE_URL=postgresql://...

# Test with Firestore in staging
export FIREBASE_PROJECT_ID=staging-project
```

**Step 2: Migrate data** (create custom script as needed)
```typescript
// migrate.ts
import { PrismaClient } from '@prisma/client';
import { getFirestoreDb } from './services/firebase.js';

// Copy all users and meal analyses from PostgreSQL to Firestore
```

**Step 3: Switch production to Firestore**
```bash
gcloud run services update nutrition-ai-backend \
  --update-env-vars FIREBASE_PROJECT_ID=production-project \
  --remove-env-vars DATABASE_URL
```

## 📊 Cost Comparison

| Feature | Firestore (Free Tier) | Cloud SQL (Smallest) |
|---------|----------------------|---------------------|
| Storage | 1 GB | 10 GB |
| Reads | 50,000/day | Unlimited |
| Writes | 20,000/day | Unlimited |
| **Cost** | **$0** | **~$7-10/month** |
| Setup | None | 5-10 minutes |
| Scaling | Automatic | Manual |

**Most apps stay in Firestore's free tier! 🎉**

## 🔐 Security

Both database options include:
- ✅ User authentication with JWT
- ✅ Password hashing with bcrypt
- ✅ Input validation
- ✅ Rate limiting (100 req/hour)
- ✅ File size limits (5MB)

**Firestore-specific:**
- Security rules for client access
- Server-side (Cloud Run) has full access via Admin SDK

## 📚 Next Steps

1. **[Read Firebase Deployment Guide](FIREBASE_DEPLOYMENT.md)** for detailed setup
2. **Test locally** with `./test-db.sh`
3. **Deploy to Cloud Run** following QUICKSTART.md
4. **Update iOS app** with your Cloud Run URL

## 🆘 Support

- **Firebase issues**: See [FIREBASE_DEPLOYMENT.md](FIREBASE_DEPLOYMENT.md) troubleshooting section
- **PostgreSQL issues**: See [DEPLOYMENT.md](DEPLOYMENT.md) troubleshooting section
- **General backend**: See [README.md](README.md)

## 🎉 Benefits Summary

✅ **Zero lock-in** - Switch databases anytime with one environment variable
✅ **Cost-effective** - Start free with Firestore, scale when needed
✅ **Production-ready** - Both options battle-tested
✅ **Type-safe** - Full TypeScript support
✅ **Flexible** - Choose the right database for your use case

Your backend is now ready to deploy with Firebase Firestore! 🚀

# Firebase Deployment Guide

This guide shows how to deploy your Nutrition AI backend to Firebase with Firestore database.

## Why Firebase?

- **Firestore**: NoSQL database included for free (up to 1GB storage, 50K reads/day)
- **Cloud Run**: Serverless hosting with automatic scaling
- **No separate database setup**: Firestore is built-in to Firebase projects
- **Generous free tier**: Most small apps stay completely free

## Prerequisites

1. **Google Cloud account** (free tier available)
2. **Firebase project** (create at [console.firebase.google.com](https://console.firebase.google.com))
3. **gcloud CLI** installed and authenticated

## Quick Setup (3 Steps)

### Step 1: Create Firebase Project

```bash
# Login to Firebase
firebase login

# Create a new project (or use existing)
firebase projects:create nutrition-ai-app

# Or list existing projects
firebase projects:list

# Set the project
firebase use nutrition-ai-app
```

Alternatively, create via web console: [console.firebase.google.com](https://console.firebase.google.com)

### Step 2: Enable Firestore

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click "Firestore Database" in the left menu
4. Click "Create database"
5. Choose **Production mode**
6. Select a region (e.g., `us-central1`)

Or via CLI:
```bash
# Get your project ID
firebase projects:list

# Enable Firestore
gcloud firestore databases create --project=YOUR_PROJECT_ID --location=us-central1
```

### Step 3: Deploy to Cloud Run with Firebase

```bash
cd backend

# Deploy with Firebase/Firestore configuration
gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --project YOUR_PROJECT_ID \
  --set-env-vars "FIREBASE_PROJECT_ID=YOUR_PROJECT_ID,GEMINI_API_KEY=YOUR_GEMINI_KEY,JWT_SECRET=$(openssl rand -base64 32)"
```

That's it! The backend will automatically:
- Detect Firebase configuration
- Use Firestore instead of PostgreSQL
- Create collections as needed

## Configuration Details

### Environment Variables

Set these in Cloud Run:

```bash
FIREBASE_PROJECT_ID=your-project-id      # Required for Firestore
GEMINI_API_KEY=your_gemini_key           # Required for AI analysis
JWT_SECRET=your_random_secret            # Required for auth
DATABASE_TYPE=firestore                  # Optional - auto-detected
```

### Authentication

Cloud Run automatically has access to Firebase in the same project via **Application Default Credentials**. No service account JSON needed!

If deploying to a different project, create a service account:

```bash
# Create service account
gcloud iam service-accounts create nutrition-ai \
  --display-name="Nutrition AI Backend"

# Grant Firestore access
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:nutrition-ai@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

# Create key (optional - only if not using same project)
gcloud iam service-accounts keys create service-account.json \
  --iam-account=nutrition-ai@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Add as secret in Cloud Run
gcloud secrets create firebase-service-account --data-file=service-account.json
```

## Firestore Security Rules

Set up security rules in Firebase Console or via CLI:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can only read their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Meal analyses - users can read/write their own meals
    match /mealAnalyses/{analysisId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
      allow create: if request.auth != null;
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

## Firestore Indexes

Firestore auto-creates most indexes. For complex queries, create manually:

```javascript
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "mealAnalyses",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

Deploy:
```bash
firebase deploy --only firestore:indexes
```

## Data Migration (PostgreSQL → Firestore)

If you have existing PostgreSQL data to migrate:

```bash
# Export from PostgreSQL
pg_dump -U user -d nutritionai --data-only --table=users --table=meal_analyses > data.sql

# Or use a custom migration script
npm run migrate:firestore
```

Create migration script (`src/scripts/migrate.ts`):

```typescript
import { PrismaClient } from '@prisma/client';
import { getFirestoreDb } from '../services/firebase.js';

const prisma = new PrismaClient();
const firestore = getFirestoreDb();

async function migrate() {
  // Migrate users
  const users = await prisma.user.findMany();
  for (const user of users) {
    await firestore.collection('users').doc(user.id).set({
      email: user.email,
      passwordHash: user.passwordHash,
      name: user.name,
      createdAt: user.createdAt
    });
  }
  
  // Migrate meal analyses
  const meals = await prisma.mealAnalysis.findMany();
  for (const meal of meals) {
    await firestore.collection('mealAnalyses').doc(meal.id).set({
      userId: meal.userId,
      imageUrl: meal.imageUrl,
      nutritionData: meal.nutritionData,
      createdAt: meal.createdAt
    });
  }
  
  console.log('Migration complete!');
}

migrate();
```

## Testing Locally with Firestore

```bash
# Set environment variables
export FIREBASE_PROJECT_ID=your-project-id
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
export GEMINI_API_KEY=your_key
export JWT_SECRET=your_secret

# Run locally
npm run dev
```

Or use Firestore emulator for local development:

```bash
# Install and start emulator
firebase emulators:start

# In .env
FIRESTORE_EMULATOR_HOST=localhost:8080
FIREBASE_PROJECT_ID=demo-project
```

## Monitoring & Debugging

### View Firestore Data
- [Firebase Console](https://console.firebase.google.com) → Firestore Database

### View Logs
```bash
gcloud run services logs tail nutrition-ai-backend --region us-central1
```

### Check Database Connection
```bash
curl https://your-app.run.app/health
```

## Cost Comparison

### Firestore (Free Tier)
- **Storage**: 1 GB
- **Reads**: 50,000/day
- **Writes**: 20,000/day
- **Deletes**: 20,000/day
- Most apps stay FREE ✅

### Cloud SQL PostgreSQL
- **Smallest instance**: ~$7-10/month
- **Storage**: $0.17/GB/month
- Better for complex relational queries

## Switching Between Databases

The backend automatically detects which database to use:

### Use Firestore (Production)
```bash
# Cloud Run
gcloud run services update nutrition-ai-backend \
  --set-env-vars FIREBASE_PROJECT_ID=your-project-id
```

### Use PostgreSQL (Local/Development)
```bash
# Just set DATABASE_URL
export DATABASE_URL=postgresql://localhost/nutritionai
# Don't set FIREBASE_PROJECT_ID
```

### Force a specific database
```bash
export DATABASE_TYPE=firestore  # or 'postgres'
```

## Troubleshooting

### "Permission denied" errors
- Check Firestore security rules
- Verify service account has `roles/datastore.user` role
- Ensure FIREBASE_PROJECT_ID is correct

### "Firestore not initialized"
- Verify FIREBASE_PROJECT_ID is set
- Check Cloud Run has access to Firebase project
- Review Cloud Run logs for initialization errors

### Data not appearing
- Check Firestore console to verify data is written
- Review security rules - they might be blocking reads
- Check userId matches in JWT token and Firestore docs

## Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Firestore Pricing](https://firebase.google.com/pricing)

## Quick Reference Commands

```bash
# Deploy to Cloud Run with Firestore
gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --project YOUR_PROJECT_ID \
  --set-env-vars FIREBASE_PROJECT_ID=YOUR_PROJECT_ID

# View Firestore data
firebase firestore:query mealAnalyses --limit 10

# Export Firestore data
gcloud firestore export gs://your-bucket/backup

# Import Firestore data
gcloud firestore import gs://your-bucket/backup
```

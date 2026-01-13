# 🚀 Firebase Deployment Checklist

Use this checklist to deploy your Nutrition AI backend to Firebase with Firestore.

## ☑️ Pre-Deployment

- [ ] Google Cloud account created
- [ ] gcloud CLI installed (`gcloud --version`)
- [ ] Firebase CLI installed (`firebase --version`)
- [ ] Logged in to both (`gcloud auth login && firebase login`)

## ☑️ Step 1: Create Firebase Project

- [ ] Create project: `firebase projects:create nutrition-ai-app`
- [ ] Or use existing: `firebase projects:list`
- [ ] Set active project: `firebase use nutrition-ai-app`
- [ ] Note your project ID: ________________

## ☑️ Step 2: Enable Firestore Database

Choose one method:

**Method A: Firebase Console (Easiest)**
- [ ] Go to [console.firebase.google.com](https://console.firebase.google.com)
- [ ] Select your project
- [ ] Click "Firestore Database" → "Create database"
- [ ] Choose "Production mode"
- [ ] Select region (us-central1 recommended)

**Method B: gcloud CLI**
```bash
gcloud firestore databases create \
  --project=nutrition-ai-app \
  --location=us-central1
```

- [ ] Firestore database created

## ☑️ Step 3: Get API Keys

- [ ] Get Gemini API key from [makersuite.google.com/app/apikey](https://makersuite.google.com/app/apikey)
- [ ] Save your key: ________________

## ☑️ Step 4: Deploy to Cloud Run

```bash
cd backend

gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --project nutrition-ai-app \
  --set-env-vars "FIREBASE_PROJECT_ID=nutrition-ai-app,GEMINI_API_KEY=YOUR_KEY,JWT_SECRET=$(openssl rand -base64 32)"
```

Replace `YOUR_KEY` with your actual Gemini API key.

- [ ] Deployment started
- [ ] Build successful
- [ ] Service deployed

## ☑️ Step 5: Get Service URL

```bash
gcloud run services describe nutrition-ai-backend \
  --region us-central1 \
  --format="value(status.url)"
```

- [ ] Service URL obtained: ________________________________

## ☑️ Step 6: Test Deployment

```bash
# Health check
curl https://YOUR_SERVICE_URL/health

# Should return: {"status":"ok"}
```

- [ ] Health check passed
- [ ] Service responding

## ☑️ Step 7: Update iOS App

In your iOS app, update the API endpoint:

```swift
// In APIService.swift or config
private let baseURL = "https://YOUR_SERVICE_URL"
```

- [ ] iOS app updated with new URL
- [ ] iOS app tested with backend

## ☑️ Post-Deployment (Optional)

### Set up Firestore Security Rules

```bash
# Create firestore.rules
cat > firestore.rules << 'EOF'
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /mealAnalyses/{analysisId} {
      allow read, write: if request.auth != null;
    }
  }
}
EOF

# Deploy rules
firebase deploy --only firestore:rules
```

- [ ] Security rules created
- [ ] Security rules deployed

### Set up Monitoring

- [ ] Enable Cloud Logging
- [ ] Set up error alerting
- [ ] Monitor quotas

### Create Firestore Indexes (if needed)

```bash
# Create firestore.indexes.json
cat > firestore.indexes.json << 'EOF'
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
EOF

# Deploy indexes
firebase deploy --only firestore:indexes
```

- [ ] Indexes created
- [ ] Indexes deployed

## 📊 Verify Everything Works

Test all endpoints:

### 1. Register User
```bash
curl -X POST https://YOUR_SERVICE_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "Test User"
  }'
```

- [ ] User registration works
- [ ] JWT token received

### 2. Login
```bash
curl -X POST https://YOUR_SERVICE_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

- [ ] Login works
- [ ] JWT token received

### 3. Check Firestore Data

- [ ] Go to Firebase Console → Firestore Database
- [ ] Verify `users` collection exists
- [ ] Verify user document was created

### 4. Analyze Image (via iOS app)
- [ ] Open iOS app
- [ ] Take/upload food photo
- [ ] Verify analysis works
- [ ] Check Firestore for `mealAnalyses` document

## 🎯 Success Criteria

✅ All endpoints respond correctly
✅ Data appears in Firestore console
✅ iOS app works end-to-end
✅ No errors in Cloud Run logs

## 📝 Important Info to Save

```
Project ID:     ____________________
Cloud Run URL:  ____________________
Region:         us-central1
Database Type:  Firestore
Gemini API Key: ____________________
```

## 🆘 Troubleshooting

**Deployment fails?**
- Check gcloud authentication: `gcloud auth list`
- Verify project exists: `firebase projects:list`
- Check build logs: `gcloud builds list`

**Service not accessible?**
- Verify `--allow-unauthenticated` was set
- Check IAM permissions
- Review Cloud Run logs: `gcloud run services logs tail nutrition-ai-backend --region us-central1`

**Firestore errors?**
- Verify database was created: Check Firebase Console
- Check FIREBASE_PROJECT_ID matches your project
- Review service logs for connection errors

**Need help?**
- See [FIREBASE_DEPLOYMENT.md](FIREBASE_DEPLOYMENT.md) for detailed troubleshooting
- Check logs: `gcloud run services logs tail nutrition-ai-backend --region us-central1`
- Review Firestore quotas: [Firebase Console → Usage](https://console.firebase.google.com)

## ✨ You're Done!

Your Nutrition AI backend is now running on Firebase with Firestore! 🎉

**Next Steps:**
- Monitor usage in Firebase Console
- Set up custom domain (optional)
- Configure automatic backups
- Set up CI/CD with GitHub Actions

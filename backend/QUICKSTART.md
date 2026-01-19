# Google Cloud Run Deployment - Quick Start

## Prerequisites Checklist

- [ ] Google Cloud account with billing enabled
- [ ] gcloud CLI installed and authenticated
- [ ] Project created in Google Cloud Console
- [ ] APIs enabled (Cloud Run, Cloud Build)

## Choose Your Database

### Option A: Firebase Firestore (Recommended - Easiest!)

**Pros:**
- ✅ No separate database setup
- ✅ Free tier: 1GB storage, 50K reads/day
- ✅ Auto-scales
- ✅ Built-in to Firebase

**Quick Deploy (3 Steps):**

```bash
# 1. Create Firebase project
firebase login
firebase projects:create nutrition-ai-app
firebase use nutrition-ai-app

# 2. Enable Firestore (via web console or CLI)
# Go to console.firebase.google.com → Firestore Database → Create

# 3. Deploy
cd backend
gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars FIREBASE_PROJECT_ID=nutrition-ai-app,GEMINI_API_KEY=YOUR_KEY,JWT_SECRET=$(openssl rand -base64 32)
```

**See [FIREBASE_DEPLOYMENT.md](./FIREBASE_DEPLOYMENT.md) for detailed Firebase instructions**

---

### Option B: PostgreSQL (Cloud SQL or External)

**Pros:**
- ✅ Relational database
- ✅ Complex queries
- ✅ Better for existing SQL apps

**Cost:** ~$7/month for smallest Cloud SQL instance

**Deploy Steps:**

### 1. Authenticate and Set Project

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Enable Required APIs

```bash
gcloud services enable run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com
```

### 3. Create Secrets

```bash
# Get your Gemini API key from: https://makersuite.google.com/app/apikey

echo -n "YOUR_GEMINI_API_KEY" | gcloud secrets create gemini-api-key --data-file=-
echo -n "$(openssl rand -base64 32)" | gcloud secrets create jwt-secret --data-file=-
echo -n "YOUR_DATABASE_URL" | gcloud secrets create database-url --data-file=-

# Grant access to Cloud Run service account
PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) --format="value(projectNumber)")

for secret in gemini-api-key jwt-secret database-url; do
  gcloud secrets add-iam-policy-binding $secret \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

### 4. Deploy to Cloud Run

```bash
cd backend

gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --update-secrets GEMINI_API_KEY=gemini-api-key:latest,JWT_SECRET=jwt-secret:latest,DATABASE_URL=database-url:latest \
  --set-env-vars NODE_ENV=production
```

### 5. Get Your Service URL

```bash
gcloud run services describe nutrition-ai-backend --region us-central1 --format="value(status.url)"
```

## Database Setup Options

### Option A: Use Supabase (Easiest)

1. Go to [supabase.com](https://supabase.com) and create a free project
2. Get your connection string from Project Settings → Database
3. Use it in step 3 above as `DATABASE_URL`

### Option B: Use Cloud SQL

```bash
# Create instance (takes ~5 minutes)
gcloud sql instances create nutrition-ai-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-central1

# Create database and user
gcloud sql databases create nutritionai --instance=nutrition-ai-db
gcloud sql users create nutritionai --instance=nutrition-ai-db --password=$(openssl rand -base64 20)

# Get connection string
INSTANCE_CONNECTION_NAME=$(gcloud sql instances describe nutrition-ai-db --format="value(connectionName)")
echo "DATABASE_URL=postgresql://nutritionai:PASSWORD@localhost/nutritionai?host=/cloudsql/$INSTANCE_CONNECTION_NAME"

# Update the secret
echo -n "postgresql://nutritionai:PASSWORD@localhost/nutritionai?host=/cloudsql/$INSTANCE_CONNECTION_NAME" | \
  gcloud secrets versions add database-url --data-file=-

# Redeploy with Cloud SQL connection
gcloud run services update nutrition-ai-backend \
  --region us-central1 \
  --add-cloudsql-instances $INSTANCE_CONNECTION_NAME
```

## Update iOS App

After deployment, update your iOS app's API endpoint:

1. Get your Cloud Run URL:
   ```bash
   gcloud run services describe nutrition-ai-backend --region us-central1 --format="value(status.url)"
   ```

2. Update `APIService.swift`:
   ```swift
   private let baseURL = "https://nutrition-ai-backend-xxxxx-uc.a.run.app"
   ```

## Common Commands

```bash
# View logs
gcloud run services logs tail nutrition-ai-backend --region us-central1

# Update environment variables
gcloud run services update nutrition-ai-backend \
  --region us-central1 \
  --update-env-vars NEW_VAR=value

# Redeploy latest code
gcloud run deploy nutrition-ai-backend --source . --region us-central1

# Check service status
gcloud run services describe nutrition-ai-backend --region us-central1
```

## Troubleshooting

**Build failing?**
```bash
# Check build logs
gcloud builds list --limit=5
gcloud builds log $(gcloud builds list --limit=1 --format="value(id)")
```

**Service not starting?**
```bash
# Check runtime logs
gcloud run services logs read nutrition-ai-backend --region us-central1 --limit=50
```

**Database connection issues?**
- Verify DATABASE_URL secret is correct
- Check Cloud SQL instance is running
- Ensure Cloud SQL client IAM role is granted

**Need help?**
See full documentation in [DEPLOYMENT.md](./DEPLOYMENT.md)

## Cost Estimate

Free tier includes:
- 2M Cloud Run requests/month
- 360,000 GB-seconds compute time
- Cloud SQL: db-f1-micro instance (~$7/month)

Most development/small apps stay within free tier!

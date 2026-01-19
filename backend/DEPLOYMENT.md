# Deployment Guide - Google Cloud Run

This guide explains how to deploy the Nutrition AI backend to Google Cloud Run.

## Prerequisites

- [Google Cloud SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/install) installed
- A Google Cloud Project with billing enabled
- Firebase CLI installed (already done via `npm install -g firebase-tools`)
- Docker installed (optional, Cloud Run can build from source)

## Setup

### 1. Authenticate with Google Cloud

```bash
# Login to Google Cloud
gcloud auth login

# Set your project ID (replace with your actual project ID)
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable sqladmin.googleapis.com
```

### 2. Set up Cloud SQL (PostgreSQL Database)

You have two options:

#### Option A: Use Cloud SQL (Recommended for Production)

```bash
# Create a PostgreSQL instance
gcloud sql instances create nutrition-ai-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-central1

# Create a database
gcloud sql databases create nutritionai \
  --instance=nutrition-ai-db

# Create a user
gcloud sql users create nutritionai \
  --instance=nutrition-ai-db \
  --password=YOUR_SECURE_PASSWORD

# Get the connection name (you'll need this)
gcloud sql instances describe nutrition-ai-db --format="value(connectionName)"
# Output format: PROJECT_ID:REGION:INSTANCE_NAME
```

#### Option B: Use External PostgreSQL (e.g., Supabase, Neon, or your own)

If using an external database, you'll just need the connection URL.

### 3. Configure Environment Variables

Cloud Run requires environment variables to be set during deployment. You'll need:

- `DATABASE_URL`: PostgreSQL connection string
- `GEMINI_API_KEY`: Your Google Gemini API key
- `JWT_SECRET`: Secret key for JWT tokens

**For Cloud SQL:**
```
DATABASE_URL=postgresql://nutritionai:YOUR_PASSWORD@/nutritionai?host=/cloudsql/PROJECT_ID:REGION:INSTANCE_NAME
```

**For External Database:**
```
DATABASE_URL=postgresql://user:password@host:5432/database
```

### 4. Deploy to Cloud Run

```bash
cd backend

# Deploy (this will build and deploy in one command)
gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "GEMINI_API_KEY=your_gemini_key_here,JWT_SECRET=your_jwt_secret_here" \
  --set-env-vars "DATABASE_URL=your_database_url_here" \
  --add-cloudsql-instances PROJECT_ID:REGION:INSTANCE_NAME
```

**Note:** Replace the placeholders:
- `your_gemini_key_here` - Your Gemini API key
- `your_jwt_secret_here` - A secure random string for JWT
- `your_database_url_here` - Your database connection string
- `PROJECT_ID:REGION:INSTANCE_NAME` - Only if using Cloud SQL

Or use the npm script:
```bash
npm run deploy
```

Then set environment variables via the Cloud Console or gcloud.

### 5. Set Environment Variables After Deployment

If you didn't set them during initial deployment, you can add them later:

```bash
# Update environment variables
gcloud run services update nutrition-ai-backend \
  --region us-central1 \
  --update-env-vars "GEMINI_API_KEY=your_key,JWT_SECRET=your_secret,DATABASE_URL=your_db_url"

# For Cloud SQL connection (add --add-cloudsql-instances)
gcloud run services update nutrition-ai-backend \
  --region us-central1 \
  --add-cloudsql-instances PROJECT_ID:REGION:INSTANCE_NAME
```

### 6. Run Database Migrations

The Dockerfile is configured to run Prisma migrations automatically on startup via:
```bash
npx prisma migrate deploy && npm start
```

If you need to run migrations manually:

```bash
# Connect to Cloud SQL locally
gcloud sql connect nutrition-ai-db --user=nutritionai --database=nutritionai

# Or use Cloud Shell
gcloud cloud-shell ssh
cd backend
DATABASE_URL="your_connection_string" npx prisma migrate deploy
```

## Post-Deployment

### Get Your Service URL

```bash
gcloud run services describe nutrition-ai-backend \
  --region us-central1 \
  --format="value(status.url)"
```

Example output: `https://nutrition-ai-backend-xxxxx-uc.a.run.app`

### Test Your Deployment

```bash
# Health check
curl https://nutrition-ai-backend-xxxxx-uc.a.run.app/health

# Should return: {"status":"ok"}
```

### Update iOS App

Update the API base URL in your iOS app to point to your Cloud Run service:

```swift
// In APIService.swift or your config
let baseURL = "https://nutrition-ai-backend-xxxxx-uc.a.run.app"
```

## Managing Secrets Securely

For better security, use Google Secret Manager instead of environment variables:

```bash
# Enable Secret Manager API
gcloud services enable secretmanager.googleapis.com

# Create secrets
echo -n "your_gemini_key" | gcloud secrets create gemini-api-key --data-file=-
echo -n "your_jwt_secret" | gcloud secrets create jwt-secret --data-file=-
echo -n "your_database_url" | gcloud secrets create database-url --data-file=-

# Grant Cloud Run service account access
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format="value(projectNumber)")

gcloud secrets add-iam-policy-binding gemini-api-key \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Repeat for other secrets...

# Deploy with secrets
gcloud run deploy nutrition-ai-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --update-secrets GEMINI_API_KEY=gemini-api-key:latest \
  --update-secrets JWT_SECRET=jwt-secret:latest \
  --update-secrets DATABASE_URL=database-url:latest
```

## Monitoring and Logs

```bash
# View logs
gcloud run services logs read nutrition-ai-backend --region us-central1

# Follow logs in real-time
gcloud run services logs tail nutrition-ai-backend --region us-central1
```

## Cost Optimization

Cloud Run charges based on usage:
- **Free tier:** 2 million requests/month, 360,000 GB-seconds/month
- **Pricing:** After free tier, pay per request and compute time

Tips to reduce costs:
1. Set minimum instances to 0 (default) - scales to zero when not in use
2. Set appropriate CPU and memory limits
3. Use Cloud SQL's smallest instance tier for development

```bash
# Set resource limits
gcloud run services update nutrition-ai-backend \
  --region us-central1 \
  --cpu=1 \
  --memory=512Mi \
  --min-instances=0 \
  --max-instances=10
```

## Troubleshooting

### Database Connection Issues

If you get connection errors:

1. Verify Cloud SQL instance is running:
   ```bash
   gcloud sql instances list
   ```

2. Check connection name is correct:
   ```bash
   gcloud sql instances describe nutrition-ai-db --format="value(connectionName)"
   ```

3. Ensure service has Cloud SQL client role:
   ```bash
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
     --role="roles/cloudsql.client"
   ```

### Build Failures

Check Cloud Build logs:
```bash
gcloud builds list --limit=5
gcloud builds log BUILD_ID
```

### Service Not Starting

View detailed logs:
```bash
gcloud run services logs read nutrition-ai-backend --region us-central1 --limit=50
```

## Alternative: Deploy with Docker

If you prefer to build locally:

```bash
# Build the image
docker build -t gcr.io/YOUR_PROJECT_ID/nutrition-ai-backend .

# Push to Google Container Registry
docker push gcr.io/YOUR_PROJECT_ID/nutrition-ai-backend

# Deploy
gcloud run deploy nutrition-ai-backend \
  --image gcr.io/YOUR_PROJECT_ID/nutrition-ai-backend \
  --region us-central1 \
  --allow-unauthenticated
```

## Quick Reference

```bash
# One-command deploy
npm run deploy

# View service status
gcloud run services describe nutrition-ai-backend --region us-central1

# Update code
gcloud run deploy nutrition-ai-backend --source . --region us-central1

# Delete service
gcloud run services delete nutrition-ai-backend --region us-central1

# Delete Cloud SQL instance
gcloud sql instances delete nutrition-ai-db
```

## Next Steps

1. Set up custom domain (optional)
2. Configure CORS for your iOS app domain
3. Set up CI/CD with GitHub Actions
4. Enable Cloud Monitoring and Alerting
5. Set up automated backups for Cloud SQL

For more information:
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Prisma with Cloud SQL](https://www.prisma.io/docs/guides/deployment/deployment-guides/deploying-to-google-cloud-run)

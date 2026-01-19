# NutritionAI Web App Deployment Guide

This guide covers deploying the NutritionAI web app to Firebase Hosting and setting up the backend for production.

## Table of Contents
- [Firebase Hosting Setup](#firebase-hosting-setup)
- [Backend Deployment](#backend-deployment)
- [Testing Locally Before Deploy](#testing-locally-before-deploy)
- [Production Checklist](#production-checklist)
- [Troubleshooting](#troubleshooting)

## Firebase Hosting Setup

The web app is configured to deploy to Firebase Hosting for project `nutritionai2026`.

### Prerequisites

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

### Environment Variables

Create a `.env.production` file in the `web/` directory with:

```env
VITE_API_BASE_URL=https://your-backend-url.com
VITE_SHOW_API_OVERRIDE=false
```

Replace `https://your-backend-url.com` with your actual backend API URL.

### Build and Deploy

1. Build the web app:
   ```bash
   cd web
   npm run build
   ```

2. Deploy to Firebase Hosting:
   ```bash
   cd ..
   firebase deploy --only hosting
   ```

### Post-Deployment

After deployment, your app will be available at:
- `https://nutritionai2026.web.app`
- `https://nutritionai2026.firebaseapp.com`

### Backend CORS Configuration

The backend is configured to accept requests from all origins (`origin: true` in CORS config).

For production, you should update `backend/src/server.ts` to restrict CORS to your Firebase Hosting domain:

```typescript
await server.register(cors, {
  origin: [
    'https://nutritionai2026.web.app',
    'https://nutritionai2026.firebaseapp.com',
    'http://localhost:5173' // for local development
  ]
});
```

### Verify Deployment

1. Visit your Firebase Hosting URL
2. Try logging in or using guest mode
3. Test camera capture and meal analysis
4. Verify stats and history load correctly

## Backend Deployment

The backend needs to be deployed to a Node.js hosting service with PostgreSQL support.

### Recommended Platforms
- **Railway** - Easy PostgreSQL provisioning, auto-deploys from GitHub
- **Render** - Free tier available, managed PostgreSQL
- **Fly.io** - Edge deployment, PostgreSQL add-on
- **AWS/GCP/Azure** - Full control, requires more setup

### Railway Deployment (Recommended)

1. Create a Railway account at https://railway.app

2. Create a new project and add PostgreSQL:
   ```
   New Project → Add PostgreSQL
   ```

3. Add the backend service:
   ```
   New → GitHub Repo → Select your repo
   Set root directory to: backend
   ```

4. Configure environment variables:
   ```
   PORT=3000
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   JWT_SECRET=your-secure-secret-here
   GEMINI_API_KEY=your-gemini-api-key
   ```

5. Deploy and get your backend URL (e.g., `https://nutritionai-backend.up.railway.app`)

### After Backend Deployment

1. Update `web/.env.production`:
   ```env
   VITE_API_BASE_URL=https://your-backend-url.com
   ```

2. Rebuild and redeploy the web app:
   ```bash
   cd web
   npm run build
   cd ..
   firebase deploy --only hosting
   ```

## Troubleshooting

### CORS Errors

If you see CORS errors after deployment:
1. Check that your backend CORS config includes the Firebase Hosting domain
2. Verify the `VITE_API_BASE_URL` is set correctly
3. Ensure your backend is accessible from the Firebase Hosting domain

### Build Errors

If the build fails:
1. Clear the build cache: `rm -rf web/dist`
2. Reinstall dependencies: `cd web && npm ci`
3. Run typecheck: `npm run typecheck`

### API Connection Issues

If the app can't connect to the backend:
1. Check browser console for errors
2. Verify `VITE_API_BASE_URL` in your .env file
3. Test the backend URL directly in your browser
4. Check backend logs for authentication/authorization errors

## Testing Locally Before Deploy

Before deploying to production, test the complete flow locally:

### 1. Start Backend Server
```bash
cd backend
npm install
npm run dev
```

### 2. Build and Preview Web App
```bash
cd web
npm run build
npm run preview
```

### 3. Test Checklist
- [ ] Register a new user account
- [ ] Login with existing credentials
- [ ] Try guest mode
- [ ] View Home dashboard with stats
- [ ] Capture photo with camera (requires HTTPS or localhost)
- [ ] Upload photo via file picker
- [ ] Submit photo for analysis
- [ ] View nutrition results
- [ ] Check meal history
- [ ] View meal detail
- [ ] Toggle theme in Settings
- [ ] Change AI model in Settings
- [ ] Logout and verify redirect to login

## Production Checklist

Before going live, ensure:

### Backend
- [ ] Backend deployed to production server (e.g., Railway, Render, AWS)
- [ ] PostgreSQL database provisioned and migrated
- [ ] `JWT_SECRET` set to a strong, unique value
- [ ] `GEMINI_API_KEY` configured
- [ ] CORS configured to allow Firebase Hosting domains only
- [ ] Rate limiting enabled

### Frontend
- [ ] `VITE_API_BASE_URL` points to production backend
- [ ] `VITE_SHOW_API_OVERRIDE=false` in production
- [ ] Build passes without TypeScript errors
- [ ] All tests pass

### Firebase
- [ ] Firebase project created
- [ ] Firebase CLI authenticated
- [ ] `firebase.json` points to `web/dist`
- [ ] `.firebaserc` has correct project ID

## Firebase Configuration Files

### firebase.json
```json
{
  "hosting": {
    "public": "web/dist",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      { "source": "**", "destination": "/index.html" }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }]
      }
    ]
  }
}
```

### .firebaserc
```json
{
  "projects": {
    "default": "nutritionai2026"
  }
}
```

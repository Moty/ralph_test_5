# NutritionAI Web App Deployment Guide

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

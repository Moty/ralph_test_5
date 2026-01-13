import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';

let firebaseApp: admin.app.App | null = null;
let db: FirebaseFirestore.Firestore | null = null;

/**
 * Initialize Firebase Admin SDK
 * Supports both service account JSON and Application Default Credentials
 */
export function initializeFirebase() {
  if (firebaseApp) {
    return { app: firebaseApp, db: db! };
  }

  try {
    // Check if we're in Firebase environment (Cloud Run, Cloud Functions)
    // or if GOOGLE_APPLICATION_CREDENTIALS is set
    if (process.env.FIREBASE_PROJECT_ID || process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      const config: admin.AppOptions = {};
      
      if (process.env.FIREBASE_PROJECT_ID) {
        config.projectId = process.env.FIREBASE_PROJECT_ID;
      }

      // If service account JSON is provided as a string (for Cloud Run secrets)
      if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        config.credential = admin.credential.cert(serviceAccount);
      } else {
        // Use Application Default Credentials (works in Cloud Run automatically)
        config.credential = admin.credential.applicationDefault();
      }

      firebaseApp = admin.initializeApp(config);
      db = getFirestore(firebaseApp);
      
      console.log('✅ Firebase initialized successfully');
      return { app: firebaseApp, db };
    } else {
      console.log('⚠️ Firebase not configured - using PostgreSQL');
      return { app: null, db: null };
    }
  } catch (error) {
    console.error('❌ Failed to initialize Firebase:', error);
    throw error;
  }
}

/**
 * Get Firestore instance
 */
export function getFirestoreDb(): FirebaseFirestore.Firestore {
  if (!db) {
    const initialized = initializeFirebase();
    if (!initialized.db) {
      throw new Error('Firestore is not initialized');
    }
    return initialized.db;
  }
  return db;
}

/**
 * Check if Firebase is available
 */
export function isFirebaseEnabled(): boolean {
  return db !== null || !!(process.env.FIREBASE_PROJECT_ID || process.env.GOOGLE_APPLICATION_CREDENTIALS);
}

export { admin, db };

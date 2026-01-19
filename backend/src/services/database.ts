/**
 * Database service using Firestore
 */

import { getFirestoreDb, isFirebaseEnabled } from './firebase.js';
import type { Firestore } from 'firebase-admin/firestore';
import admin from 'firebase-admin';

export interface User {
  id: string;
  email: string;
  passwordHash: string;
  name: string;
  createdAt: Date;
}

export interface MealAnalysis {
  id: string;
  userId: string | null;
  imageUrl: string;
  thumbnail: string | null;  // Base64 encoded thumbnail image
  nutritionData: any;
  createdAt: Date;
}

export interface DatabaseService {
  // User operations
  createUser(data: { email: string; passwordHash: string; name: string }): Promise<User>;
  findUserByEmail(email: string): Promise<User | null>;
  findUserById(id: string): Promise<User | null>;

  // Meal analysis operations
  createMealAnalysis(data: { userId?: string; imageUrl: string; thumbnail?: string; nutritionData: any }): Promise<MealAnalysis>;
  findMealAnalysesByUserId(userId: string): Promise<MealAnalysis[]>;
  findMealAnalysisById(id: string): Promise<MealAnalysis | null>;

  // Utility
  disconnect(): Promise<void>;
}

/**
 * Firestore implementation
 */
class FirestoreDatabase implements DatabaseService {
  private db: Firestore;

  constructor() {
    this.db = getFirestoreDb();
  }

  private generateId(): string {
    return this.db.collection('_').doc().id;
  }

  async createUser(data: { email: string; passwordHash: string; name: string }): Promise<User> {
    const id = this.generateId();
    const user: User = {
      id,
      ...data,
      createdAt: new Date()
    };

    await this.db.collection('users').doc(id).set({
      ...user,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return user;
  }

  async findUserByEmail(email: string): Promise<User | null> {
    const snapshot = await this.db.collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) return null;

    const doc = snapshot.docs[0];
    const data = doc.data();
    return {
      id: doc.id,
      email: data.email,
      passwordHash: data.passwordHash,
      name: data.name,
      createdAt: data.createdAt?.toDate() || new Date()
    };
  }

  async findUserById(id: string): Promise<User | null> {
    const doc = await this.db.collection('users').doc(id).get();

    if (!doc.exists) return null;

    const data = doc.data()!;
    return {
      id: doc.id,
      email: data.email,
      passwordHash: data.passwordHash,
      name: data.name,
      createdAt: data.createdAt?.toDate() || new Date()
    };
  }

  async createMealAnalysis(data: { userId?: string; imageUrl: string; thumbnail?: string; nutritionData: any }): Promise<MealAnalysis> {
    const id = this.generateId();
    const analysis: MealAnalysis = {
      id,
      userId: data.userId || null,
      imageUrl: data.imageUrl,
      thumbnail: data.thumbnail || null,
      nutritionData: data.nutritionData,
      createdAt: new Date()
    };

    await this.db.collection('mealAnalyses').doc(id).set({
      ...analysis,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return analysis;
  }

  async findMealAnalysesByUserId(userId: string): Promise<MealAnalysis[]> {
    try {
      // Try with orderBy (requires composite index)
      const snapshot = await this.db.collection('mealAnalyses')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .get();

      return snapshot.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          userId: data.userId,
          imageUrl: data.imageUrl,
          thumbnail: data.thumbnail || null,
          nutritionData: data.nutritionData,
          createdAt: data.createdAt?.toDate() || new Date()
        };
      });
    } catch (error: any) {
      // If index not ready, fallback to no ordering (sort in memory)
      if (error.code === 9 || error.message?.includes('index')) {
        console.log('Firestore index not ready, fetching without order...');
        const snapshot = await this.db.collection('mealAnalyses')
          .where('userId', '==', userId)
          .get();

        const meals = snapshot.docs.map(doc => {
          const data = doc.data();
          return {
            id: doc.id,
            userId: data.userId,
            imageUrl: data.imageUrl,
            thumbnail: data.thumbnail || null,
            nutritionData: data.nutritionData,
            createdAt: data.createdAt?.toDate() || new Date()
          };
        });

        // Sort in memory
        return meals.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
      }
      throw error;
    }
  }

  async findMealAnalysisById(id: string): Promise<MealAnalysis | null> {
    const doc = await this.db.collection('mealAnalyses').doc(id).get();

    if (!doc.exists) return null;

    const data = doc.data()!;
    return {
      id: doc.id,
      userId: data.userId,
      imageUrl: data.imageUrl,
      thumbnail: data.thumbnail || null,
      nutritionData: data.nutritionData,
      createdAt: data.createdAt?.toDate() || new Date()
    };
  }

  async disconnect(): Promise<void> {
    // Firestore connections are managed by Firebase Admin SDK
    // No explicit disconnect needed
  }
}

/**
 * Get the database service (Firestore)
 */
export function getDatabaseService(): DatabaseService {
  if (!isFirebaseEnabled()) {
    throw new Error('Firebase is not configured. Set FIREBASE_PROJECT_ID environment variable.');
  }
  console.log('🔥 Using Firestore database');
  return new FirestoreDatabase();
}

// Singleton instance
let dbInstance: DatabaseService | null = null;

export function getDb(): DatabaseService {
  if (!dbInstance) {
    dbInstance = getDatabaseService();
  }
  return dbInstance;
}

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

export interface UserProfile {
  id: string;
  userId: string;
  dietType: string;
  dailyCalorieGoal: number;
  dailyProteinGoal: number;
  dailyCarbsGoal: number;
  dailyFatGoal: number;
  dailyFiberGoal: number | null;
  dailySugarLimit: number | null;
  weight: number | null;
  height: number | null;
  age: number | null;
  gender: string | null;
  activityLevel: string | null;
  dietaryRestrictions: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface DietTemplate {
  id: string;
  dietType: string;
  name: string;
  description: string;
  proteinRatio: number;
  carbsRatio: number;
  fatRatio: number;
  baselineCalories: number;
  baselineProtein: number;
  baselineCarbs: number;
  baselineFat: number;
  carbsTolerance: number;
  proteinTolerance: number;
  fatTolerance: number;
  fiberMinimum: number | null;
  sugarMaximum: number | null;
}

export interface DailyProgress {
  id: string;
  userId: string;
  date: Date;
  totalCalories: number;
  totalProtein: number;
  totalCarbs: number;
  totalFat: number;
  totalFiber: number;
  totalSugar: number;
  mealCount: number;
  goalCalories: number;
  goalProtein: number;
  goalCarbs: number;
  goalFat: number;
  goalFiber: number | null;
  goalSugar: number | null;
  isOnTrack: boolean;
  carbsCompliance: number;
  proteinCompliance: number;
  fatCompliance: number;
  dietType: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface WeeklySummary {
  id: string;
  userId: string;
  weekStart: Date;
  weekEnd: Date;
  avgCalories: number;
  avgProtein: number;
  avgCarbs: number;
  avgFat: number;
  avgFiber: number;
  avgSugar: number;
  totalMeals: number;
  daysTracked: number;
  complianceRate: number;
  createdAt: Date;
}

export interface KetoneLog {
  id: string;
  userId: string;
  timestamp: Date;
  ketoneLevel: number;
  measurementType: string;
  notes: string | null;
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
  deleteMealAnalysis(id: string): Promise<void>;
  updateMealAnalysis(id: string, data: { nutritionData?: any; thumbnail?: string; createdAt?: Date }): Promise<MealAnalysis | null>;

  // User profile operations
  createUserProfile(data: Omit<UserProfile, 'id' | 'createdAt' | 'updatedAt'>): Promise<UserProfile>;
  findUserProfileByUserId(userId: string): Promise<UserProfile | null>;
  updateUserProfile(userId: string, data: Partial<Omit<UserProfile, 'id' | 'userId' | 'createdAt' | 'updatedAt'>>): Promise<UserProfile>;

  // Diet template operations
  findDietTemplateByType(dietType: string): Promise<DietTemplate | null>;
  findAllDietTemplates(): Promise<DietTemplate[]>;

  // Daily progress operations
  createOrUpdateDailyProgress(data: Omit<DailyProgress, 'id' | 'createdAt' | 'updatedAt'>): Promise<DailyProgress>;
  findDailyProgressByUserAndDate(userId: string, date: Date): Promise<DailyProgress | null>;
  findDailyProgressByUserAndDateRange(userId: string, startDate: Date, endDate: Date): Promise<DailyProgress[]>;

  // Weekly summary operations
  createWeeklySummary(data: Omit<WeeklySummary, 'id' | 'createdAt'>): Promise<WeeklySummary>;
  findWeeklySummariesByUser(userId: string, limit?: number): Promise<WeeklySummary[]>;

  // Ketone log operations
  createKetoneLog(data: Omit<KetoneLog, 'id' | 'createdAt'>): Promise<KetoneLog>;
  findKetoneLogsByUser(userId: string, limit?: number): Promise<KetoneLog[]>;
  findRecentKetoneLog(userId: string): Promise<KetoneLog | null>;
  deleteKetoneLog(id: string): Promise<void>;

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

  async deleteMealAnalysis(id: string): Promise<void> {
    await this.db.collection('mealAnalyses').doc(id).delete();
  }

  async updateMealAnalysis(id: string, data: { nutritionData?: any; thumbnail?: string; createdAt?: Date }): Promise<MealAnalysis | null> {
    const docRef = this.db.collection('mealAnalyses').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) return null;

    const updateData: any = {};
    if (data.nutritionData) updateData.nutritionData = data.nutritionData;
    if (data.thumbnail) updateData.thumbnail = data.thumbnail;
    if (data.createdAt) updateData.createdAt = admin.firestore.Timestamp.fromDate(data.createdAt);

    await docRef.update(updateData);

    const updated = await docRef.get();
    const updatedData = updated.data()!;
    return {
      id: updated.id,
      userId: updatedData.userId,
      imageUrl: updatedData.imageUrl,
      thumbnail: updatedData.thumbnail || null,
      nutritionData: updatedData.nutritionData,
      createdAt: updatedData.createdAt?.toDate() || new Date()
    };
  }

  // User profile operations
  async createUserProfile(data: Omit<UserProfile, 'id' | 'createdAt' | 'updatedAt'>): Promise<UserProfile> {
    const id = this.generateId();
    const now = new Date();
    const profile: UserProfile = {
      id,
      ...data,
      createdAt: now,
      updatedAt: now
    };

    await this.db.collection('userProfiles').doc(id).set({
      ...profile,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return profile;
  }

  async findUserProfileByUserId(userId: string): Promise<UserProfile | null> {
    const snapshot = await this.db.collection('userProfiles')
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (snapshot.empty) return null;

    const doc = snapshot.docs[0];
    const data = doc.data();
    return {
      id: doc.id,
      userId: data.userId,
      dietType: data.dietType,
      dailyCalorieGoal: data.dailyCalorieGoal,
      dailyProteinGoal: data.dailyProteinGoal,
      dailyCarbsGoal: data.dailyCarbsGoal,
      dailyFatGoal: data.dailyFatGoal,
      dailyFiberGoal: data.dailyFiberGoal || null,
      dailySugarLimit: data.dailySugarLimit || null,
      weight: data.weight || null,
      height: data.height || null,
      age: data.age || null,
      gender: data.gender || null,
      activityLevel: data.activityLevel || null,
      dietaryRestrictions: data.dietaryRestrictions || [],
      createdAt: data.createdAt?.toDate() || new Date(),
      updatedAt: data.updatedAt?.toDate() || new Date()
    };
  }

  async updateUserProfile(userId: string, data: Partial<Omit<UserProfile, 'id' | 'userId' | 'createdAt' | 'updatedAt'>>): Promise<UserProfile> {
    const existing = await this.findUserProfileByUserId(userId);
    if (!existing) throw new Error('Profile not found');

    await this.db.collection('userProfiles').doc(existing.id).update({
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const updated = await this.findUserProfileByUserId(userId);
    return updated!;
  }

  // Diet template operations
  async findDietTemplateByType(dietType: string): Promise<DietTemplate | null> {
    const snapshot = await this.db.collection('dietTemplates')
      .where('dietType', '==', dietType)
      .limit(1)
      .get();

    if (snapshot.empty) return null;

    const doc = snapshot.docs[0];
    const data = doc.data();
    return {
      id: doc.id,
      ...data
    } as DietTemplate;
  }

  async findAllDietTemplates(): Promise<DietTemplate[]> {
    const snapshot = await this.db.collection('dietTemplates').get();
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })) as DietTemplate[];
  }

  // Daily progress operations
  async createOrUpdateDailyProgress(data: Omit<DailyProgress, 'id' | 'createdAt' | 'updatedAt'>): Promise<DailyProgress> {
    const dateStr = data.date.toISOString().split('T')[0];
    const docId = `${data.userId}_${dateStr}`;

    const now = new Date();
    const existing = await this.db.collection('dailyProgress').doc(docId).get();

    const progressData = {
      ...data,
      date: admin.firestore.Timestamp.fromDate(data.date),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (existing.exists) {
      await this.db.collection('dailyProgress').doc(docId).update(progressData);
    } else {
      await this.db.collection('dailyProgress').doc(docId).set({
        ...progressData,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    return {
      id: docId,
      ...data,
      createdAt: now,
      updatedAt: now
    };
  }

  async findDailyProgressByUserAndDate(userId: string, date: Date): Promise<DailyProgress | null> {
    const dateStr = date.toISOString().split('T')[0];
    const docId = `${userId}_${dateStr}`;
    const doc = await this.db.collection('dailyProgress').doc(docId).get();

    if (!doc.exists) return null;

    const data = doc.data()!;
    return {
      id: doc.id,
      ...data,
      date: data.date?.toDate() || date,
      createdAt: data.createdAt?.toDate() || new Date(),
      updatedAt: data.updatedAt?.toDate() || new Date()
    } as DailyProgress;
  }

  async findDailyProgressByUserAndDateRange(userId: string, startDate: Date, endDate: Date): Promise<DailyProgress[]> {
    const snapshot = await this.db.collection('dailyProgress')
      .where('userId', '==', userId)
      .where('date', '>=', admin.firestore.Timestamp.fromDate(startDate))
      .where('date', '<=', admin.firestore.Timestamp.fromDate(endDate))
      .orderBy('date', 'asc')
      .get();

    return snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        ...data,
        date: data.date?.toDate() || new Date(),
        createdAt: data.createdAt?.toDate() || new Date(),
        updatedAt: data.updatedAt?.toDate() || new Date()
      } as DailyProgress;
    });
  }

  // Weekly summary operations
  async createWeeklySummary(data: Omit<WeeklySummary, 'id' | 'createdAt'>): Promise<WeeklySummary> {
    const weekStr = data.weekStart.toISOString().split('T')[0];
    const docId = `${data.userId}_${weekStr}`;
    const now = new Date();

    await this.db.collection('weeklySummaries').doc(docId).set({
      ...data,
      weekStart: admin.firestore.Timestamp.fromDate(data.weekStart),
      weekEnd: admin.firestore.Timestamp.fromDate(data.weekEnd),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      id: docId,
      ...data,
      createdAt: now
    };
  }

  async findWeeklySummariesByUser(userId: string, limit: number = 12): Promise<WeeklySummary[]> {
    const snapshot = await this.db.collection('weeklySummaries')
      .where('userId', '==', userId)
      .orderBy('weekStart', 'desc')
      .limit(limit)
      .get();

    return snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        ...data,
        weekStart: data.weekStart?.toDate() || new Date(),
        weekEnd: data.weekEnd?.toDate() || new Date(),
        createdAt: data.createdAt?.toDate() || new Date()
      } as WeeklySummary;
    });
  }

  // Ketone log operations
  async createKetoneLog(data: Omit<KetoneLog, 'id' | 'createdAt'>): Promise<KetoneLog> {
    const id = this.generateId();
    const now = new Date();

    const log: KetoneLog = {
      id,
      ...data,
      createdAt: now
    };

    await this.db.collection('ketoneLogs').doc(id).set({
      ...log,
      timestamp: admin.firestore.Timestamp.fromDate(data.timestamp),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return log;
  }

  async findKetoneLogsByUser(userId: string, limit: number = 30): Promise<KetoneLog[]> {
    const snapshot = await this.db.collection('ketoneLogs')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();

    return snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        ...data,
        timestamp: data.timestamp?.toDate() || new Date(),
        createdAt: data.createdAt?.toDate() || new Date()
      } as KetoneLog;
    });
  }

  async findRecentKetoneLog(userId: string): Promise<KetoneLog | null> {
    const logs = await this.findKetoneLogsByUser(userId, 1);
    return logs.length > 0 ? logs[0] : null;
  }

  async deleteKetoneLog(id: string): Promise<void> {
    await this.db.collection('ketoneLogs').doc(id).delete();
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

/**
 * Database abstraction layer
 * Supports both PostgreSQL (via Prisma) and Firestore
 * 
 * Usage:
 * - Set DATABASE_TYPE=firestore to use Firestore
 * - Set DATABASE_TYPE=postgres to use PostgreSQL (default)
 */

import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import { getFirestoreDb, isFirebaseEnabled } from './firebase.js';
import type { Firestore } from 'firebase-admin/firestore';
import admin from 'firebase-admin';

export type DatabaseType = 'postgres' | 'firestore';

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
 * PostgreSQL implementation using Prisma
 */
class PostgresDatabase implements DatabaseService {
  private prisma: PrismaClient;

  constructor() {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) {
      throw new Error('DATABASE_URL is required for PostgreSQL');
    }

    const pool = new Pool({ connectionString });
    const adapter = new PrismaPg(pool);
    this.prisma = new PrismaClient({ adapter });
  }

  async createUser(data: { email: string; passwordHash: string; name: string }): Promise<User> {
    const user = await this.prisma.user.create({ data });
    return {
      ...user,
      createdAt: user.createdAt
    };
  }

  async findUserByEmail(email: string): Promise<User | null> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    return user ? { ...user, createdAt: user.createdAt } : null;
  }

  async findUserById(id: string): Promise<User | null> {
    const user = await this.prisma.user.findUnique({ where: { id } });
    return user ? { ...user, createdAt: user.createdAt } : null;
  }

  async createMealAnalysis(data: { userId?: string; imageUrl: string; thumbnail?: string; nutritionData: any }): Promise<MealAnalysis> {
    const analysis = await this.prisma.mealAnalysis.create({
      data: {
        userId: data.userId || null,
        imageUrl: data.imageUrl,
        thumbnail: data.thumbnail || null,
        nutritionData: data.nutritionData
      }
    });
    return {
      ...analysis,
      thumbnail: analysis.thumbnail || null,
      createdAt: analysis.createdAt
    };
  }

  async findMealAnalysesByUserId(userId: string): Promise<MealAnalysis[]> {
    const analyses = await this.prisma.mealAnalysis.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' }
    });
    return analyses.map(a => ({ ...a, thumbnail: a.thumbnail || null, createdAt: a.createdAt }));
  }

  async findMealAnalysisById(id: string): Promise<MealAnalysis | null> {
    const analysis = await this.prisma.mealAnalysis.findUnique({ where: { id } });
    return analysis ? { ...analysis, createdAt: analysis.createdAt } : null;
  }

  async deleteMealAnalysis(id: string): Promise<void> {
    await this.prisma.mealAnalysis.delete({ where: { id } });
  }

  async updateMealAnalysis(id: string, data: { nutritionData?: any; thumbnail?: string; createdAt?: Date }): Promise<MealAnalysis | null> {
    const analysis = await this.prisma.mealAnalysis.update({
      where: { id },
      data: {
        ...(data.nutritionData && { nutritionData: data.nutritionData }),
        ...(data.thumbnail && { thumbnail: data.thumbnail }),
        ...(data.createdAt && { createdAt: data.createdAt })
      }
    });
    return analysis ? { ...analysis, createdAt: analysis.createdAt } : null;
  }

  // User profile operations
  async createUserProfile(data: Omit<UserProfile, 'id' | 'createdAt' | 'updatedAt'>): Promise<UserProfile> {
    const profile = await this.prisma.userProfile.create({ data });
    return profile as UserProfile;
  }

  async findUserProfileByUserId(userId: string): Promise<UserProfile | null> {
    const profile = await this.prisma.userProfile.findUnique({ where: { userId } });
    return profile as UserProfile | null;
  }

  async updateUserProfile(userId: string, data: Partial<Omit<UserProfile, 'id' | 'userId' | 'createdAt' | 'updatedAt'>>): Promise<UserProfile> {
    const profile = await this.prisma.userProfile.update({
      where: { userId },
      data
    });
    return profile as UserProfile;
  }

  // Diet template operations
  async findDietTemplateByType(dietType: string): Promise<DietTemplate | null> {
    const template = await this.prisma.dietTemplate.findUnique({ where: { dietType } });
    return template as DietTemplate | null;
  }

  async findAllDietTemplates(): Promise<DietTemplate[]> {
    const templates = await this.prisma.dietTemplate.findMany();
    return templates as DietTemplate[];
  }

  // Daily progress operations
  async createOrUpdateDailyProgress(data: Omit<DailyProgress, 'id' | 'createdAt' | 'updatedAt'>): Promise<DailyProgress> {
    const progress = await this.prisma.dailyProgress.upsert({
      where: {
        userId_date: {
          userId: data.userId,
          date: data.date
        }
      },
      update: data,
      create: data
    });
    return progress as DailyProgress;
  }

  async findDailyProgressByUserAndDate(userId: string, date: Date): Promise<DailyProgress | null> {
    const progress = await this.prisma.dailyProgress.findUnique({
      where: {
        userId_date: { userId, date }
      }
    });
    return progress as DailyProgress | null;
  }

  async findDailyProgressByUserAndDateRange(userId: string, startDate: Date, endDate: Date): Promise<DailyProgress[]> {
    const progress = await this.prisma.dailyProgress.findMany({
      where: {
        userId,
        date: {
          gte: startDate,
          lte: endDate
        }
      },
      orderBy: { date: 'asc' }
    });
    return progress as DailyProgress[];
  }

  // Weekly summary operations
  async createWeeklySummary(data: Omit<WeeklySummary, 'id' | 'createdAt'>): Promise<WeeklySummary> {
    const summary = await this.prisma.weeklySummary.upsert({
      where: {
        userId_weekStart: {
          userId: data.userId,
          weekStart: data.weekStart
        }
      },
      update: data,
      create: data
    });
    return summary as WeeklySummary;
  }

  async findWeeklySummariesByUser(userId: string, limit: number = 12): Promise<WeeklySummary[]> {
    const summaries = await this.prisma.weeklySummary.findMany({
      where: { userId },
      orderBy: { weekStart: 'desc' },
      take: limit
    });
    return summaries as WeeklySummary[];
  }

  // Ketone log operations
  async createKetoneLog(data: Omit<KetoneLog, 'id' | 'createdAt'>): Promise<KetoneLog> {
    const log = await this.prisma.ketoneLog.create({ data });
    return log as KetoneLog;
  }

  async findKetoneLogsByUser(userId: string, limit: number = 30): Promise<KetoneLog[]> {
    const logs = await this.prisma.ketoneLog.findMany({
      where: { userId },
      orderBy: { timestamp: 'desc' },
      take: limit
    });
    return logs as KetoneLog[];
  }

  async findRecentKetoneLog(userId: string): Promise<KetoneLog | null> {
    const log = await this.prisma.ketoneLog.findFirst({
      where: { userId },
      orderBy: { timestamp: 'desc' }
    });
    return log as KetoneLog | null;
  }

  async deleteKetoneLog(id: string): Promise<void> {
    await this.prisma.ketoneLog.delete({ where: { id } });
  }

  async disconnect(): Promise<void> {
    await this.prisma.$disconnect();
  }
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
 * Get the appropriate database service based on configuration
 */
export function getDatabaseService(): DatabaseService {
  const dbType = process.env.DATABASE_TYPE as DatabaseType | undefined;
  
  // Auto-detect: if Firebase is enabled and no explicit DATABASE_TYPE, use Firestore
  if (!dbType && isFirebaseEnabled()) {
    console.log('🔥 Using Firestore database');
    return new FirestoreDatabase();
  }
  
  if (dbType === 'firestore') {
    console.log('🔥 Using Firestore database');
    return new FirestoreDatabase();
  }
  
  console.log('🐘 Using PostgreSQL database');
  return new PostgresDatabase();
}

// Singleton instance
let dbInstance: DatabaseService | null = null;

export function getDb(): DatabaseService {
  if (!dbInstance) {
    dbInstance = getDatabaseService();
  }
  return dbInstance;
}

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
  nutritionData: any;
  createdAt: Date;
}

export interface DatabaseService {
  // User operations
  createUser(data: { email: string; passwordHash: string; name: string }): Promise<User>;
  findUserByEmail(email: string): Promise<User | null>;
  findUserById(id: string): Promise<User | null>;
  
  // Meal analysis operations
  createMealAnalysis(data: { userId?: string; imageUrl: string; nutritionData: any }): Promise<MealAnalysis>;
  findMealAnalysesByUserId(userId: string): Promise<MealAnalysis[]>;
  findMealAnalysisById(id: string): Promise<MealAnalysis | null>;
  
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

  async createMealAnalysis(data: { userId?: string; imageUrl: string; nutritionData: any }): Promise<MealAnalysis> {
    const analysis = await this.prisma.mealAnalysis.create({
      data: {
        userId: data.userId || null,
        imageUrl: data.imageUrl,
        nutritionData: data.nutritionData
      }
    });
    return {
      ...analysis,
      createdAt: analysis.createdAt
    };
  }

  async findMealAnalysesByUserId(userId: string): Promise<MealAnalysis[]> {
    const analyses = await this.prisma.mealAnalysis.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' }
    });
    return analyses.map(a => ({ ...a, createdAt: a.createdAt }));
  }

  async findMealAnalysisById(id: string): Promise<MealAnalysis | null> {
    const analysis = await this.prisma.mealAnalysis.findUnique({ where: { id } });
    return analysis ? { ...analysis, createdAt: analysis.createdAt } : null;
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

  async createMealAnalysis(data: { userId?: string; imageUrl: string; nutritionData: any }): Promise<MealAnalysis> {
    const id = this.generateId();
    const analysis: MealAnalysis = {
      id,
      userId: data.userId || null,
      imageUrl: data.imageUrl,
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

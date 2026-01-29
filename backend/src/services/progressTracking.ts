/**
 * Progress Tracking Service
 * Handles daily progress updates and weekly summary calculations
 */

import { getDb } from './database.js';
import { calculateMacroCompliance, DIET_TEMPLATES } from './dietCompliance.js';

export interface DailyProgressData {
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
}

/**
 * Update daily progress after a meal is logged
 * Recalculates totals from all meals for the day
 */
export async function updateDailyProgress(userId: string): Promise<DailyProgressData | null> {
  const db = getDb();

  // Get user profile for goals
  const profile = await db.findUserProfileByUserId(userId);
  if (!profile) {
    // User hasn't set up a profile yet, skip progress tracking
    return null;
  }

  // Get today's date (start of day in UTC)
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  // Get all meals for today
  const meals = await db.findMealAnalysesByUserId(userId);
  const todaysMeals = meals.filter(meal => {
    const mealDate = new Date(meal.createdAt);
    mealDate.setUTCHours(0, 0, 0, 0);
    return mealDate.getTime() === today.getTime();
  });

  // Calculate totals from all meals
  let totalCalories = 0;
  let totalProtein = 0;
  let totalCarbs = 0;
  let totalFat = 0;
  let totalFiber = 0;
  let totalSugar = 0;

  for (const meal of todaysMeals) {
    const data = meal.nutritionData;
    if (data?.totals) {
      totalCalories += data.totals.calories || 0;
      totalProtein += data.totals.protein || 0;
      totalCarbs += data.totals.carbs || 0;
      totalFat += data.totals.fat || 0;
      totalFiber += data.totals.fiber || 0;
      totalSugar += data.totals.sugar || 0;
    }
  }

  // Get diet template for compliance calculation
  const template = DIET_TEMPLATES[profile.dietType] || DIET_TEMPLATES.balanced;

  // Calculate compliance
  const compliance = calculateMacroCompliance(
    {
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      fiber: totalFiber,
      sugar: totalSugar
    },
    {
      calories: profile.dailyCalorieGoal,
      protein: profile.dailyProteinGoal,
      carbs: profile.dailyCarbsGoal,
      fat: profile.dailyFatGoal,
      fiber: profile.dailyFiberGoal || undefined,
      sugar: profile.dailySugarLimit || undefined
    },
    template
  );

  const progressData: DailyProgressData = {
    userId,
    date: today,
    totalCalories: Math.round(totalCalories),
    totalProtein: Math.round(totalProtein),
    totalCarbs: Math.round(totalCarbs),
    totalFat: Math.round(totalFat),
    totalFiber: Math.round(totalFiber),
    totalSugar: Math.round(totalSugar),
    mealCount: todaysMeals.length,
    goalCalories: profile.dailyCalorieGoal,
    goalProtein: profile.dailyProteinGoal,
    goalCarbs: profile.dailyCarbsGoal,
    goalFat: profile.dailyFatGoal,
    goalFiber: profile.dailyFiberGoal,
    goalSugar: profile.dailySugarLimit,
    isOnTrack: compliance.isOnTrack,
    carbsCompliance: compliance.carbsCompliance,
    proteinCompliance: compliance.proteinCompliance,
    fatCompliance: compliance.fatCompliance,
    dietType: profile.dietType
  };

  // Save or update daily progress
  await db.createOrUpdateDailyProgress(progressData);

  return progressData;
}

/**
 * Get progress data for a date range
 */
export async function getProgressRange(
  userId: string,
  startDate: Date,
  endDate: Date
): Promise<DailyProgressData[]> {
  const db = getDb();
  return await db.findDailyProgressByUserAndDateRange(userId, startDate, endDate);
}

/**
 * Calculate weekly summary from daily progress records
 */
export async function calculateWeeklySummary(
  userId: string,
  weekStart: Date
): Promise<{
  avgCalories: number;
  avgProtein: number;
  avgCarbs: number;
  avgFat: number;
  avgFiber: number;
  avgSugar: number;
  totalMeals: number;
  daysTracked: number;
  complianceRate: number;
} | null> {
  const db = getDb();

  // Calculate week end (7 days from start)
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 6);

  // Get all daily progress for the week
  const dailyProgress = await db.findDailyProgressByUserAndDateRange(userId, weekStart, weekEnd);

  if (dailyProgress.length === 0) {
    return null;
  }

  // Calculate averages
  const daysTracked = dailyProgress.length;
  const totalMeals = dailyProgress.reduce((sum, day) => sum + day.mealCount, 0);

  const avgCalories = Math.round(
    dailyProgress.reduce((sum, day) => sum + day.totalCalories, 0) / daysTracked
  );
  const avgProtein = Math.round(
    dailyProgress.reduce((sum, day) => sum + day.totalProtein, 0) / daysTracked
  );
  const avgCarbs = Math.round(
    dailyProgress.reduce((sum, day) => sum + day.totalCarbs, 0) / daysTracked
  );
  const avgFat = Math.round(
    dailyProgress.reduce((sum, day) => sum + day.totalFat, 0) / daysTracked
  );
  const avgFiber = Math.round(
    dailyProgress.reduce((sum, day) => sum + day.totalFiber, 0) / daysTracked
  );
  const avgSugar = Math.round(
    dailyProgress.reduce((sum, day) => sum + day.totalSugar, 0) / daysTracked
  );

  // Calculate compliance rate (percentage of days on track)
  const daysOnTrack = dailyProgress.filter(day => day.isOnTrack).length;
  const complianceRate = daysOnTrack / daysTracked;

  return {
    avgCalories,
    avgProtein,
    avgCarbs,
    avgFat,
    avgFiber,
    avgSugar,
    totalMeals,
    daysTracked,
    complianceRate
  };
}

/**
 * Get the start of the current week (Monday)
 */
export function getWeekStart(date: Date = new Date()): Date {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
  d.setDate(diff);
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

/**
 * Get remaining daily budget
 */
export function getRemainingBudget(progress: DailyProgressData): {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number | null;
  sugar: number | null;
} {
  return {
    calories: Math.max(0, progress.goalCalories - progress.totalCalories),
    protein: Math.max(0, progress.goalProtein - progress.totalProtein),
    carbs: Math.max(0, progress.goalCarbs - progress.totalCarbs),
    fat: Math.max(0, progress.goalFat - progress.totalFat),
    fiber: progress.goalFiber !== null ? Math.max(0, progress.goalFiber - progress.totalFiber) : null,
    sugar: progress.goalSugar !== null ? Math.max(0, progress.goalSugar - progress.totalSugar) : null
  };
}

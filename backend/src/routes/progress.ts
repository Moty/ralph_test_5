import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { getDb } from '../services/database.js';
import {
  updateDailyProgress,
  getProgressRange,
  calculateWeeklySummary,
  getWeekStart,
  getRemainingBudget
} from '../services/progressTracking.js';
import { getNextMealSuggestions, DIET_TEMPLATES, calculateNetCarbs } from '../services/dietCompliance.js';
import { authMiddleware } from '../middleware/auth.js';

export default async function progressRoutes(fastify: FastifyInstance) {
  const db = getDb();

  // Get today's progress with suggestions
  fastify.get('/api/progress/today', { preHandler: authMiddleware }, async (request: FastifyRequest, reply: FastifyReply) => {
    const userId = request.user!.userId;

    // Get user profile
    const profile = await db.findUserProfileByUserId(userId);
    if (!profile) {
      return reply.status(404).send({ error: 'Profile not set up', needsSetup: true });
    }

    // Get or calculate today's progress
    const progress = await updateDailyProgress(userId);
    if (!progress) {
      return reply.status(500).send({ error: 'Failed to calculate progress' });
    }

    // Calculate remaining budget
    const remaining = getRemainingBudget(progress);

    // Get meal suggestions based on remaining budget
    const suggestions = getNextMealSuggestions(
      remaining.calories,
      remaining.protein,
      remaining.carbs,
      remaining.fat,
      profile.dietType
    );

    // Calculate net carbs for keto users
    const netCarbs = profile.dietType === 'keto'
      ? calculateNetCarbs(progress.totalCarbs, progress.totalFiber)
      : null;

    return {
      progress: {
        ...progress,
        netCarbs
      },
      remaining,
      suggestions,
      dietType: profile.dietType,
      template: DIET_TEMPLATES[profile.dietType] || DIET_TEMPLATES.balanced
    };
  });

  // Get this week's progress
  fastify.get('/api/progress/week', { preHandler: authMiddleware }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const userId = request.user!.userId;

      const profile = await db.findUserProfileByUserId(userId);
      if (!profile) {
        return reply.status(404).send({ error: 'Profile not set up', needsSetup: true });
      }

      // Get week boundaries
      const weekStart = getWeekStart();
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 6);

      // Get daily progress for each day
      const days = await getProgressRange(userId, weekStart, weekEnd);

      // Calculate weekly summary
      const summary = await calculateWeeklySummary(userId, weekStart);

      return {
        weekStart: weekStart.toISOString().split('T')[0],
        weekEnd: weekEnd.toISOString().split('T')[0],
        days: days.map(d => ({
          ...d,
          date: typeof d.date === 'string' ? d.date : (d.date as Date).toISOString().split('T')[0]
        })),
        summary: summary || {
          avgCalories: 0,
          avgProtein: 0,
          avgCarbs: 0,
          avgFat: 0,
          avgFiber: 0,
          avgSugar: 0,
          totalMeals: 0,
          daysTracked: 0,
          complianceRate: 0
        },
        dietType: profile.dietType
      };
    } catch (error) {
      console.error('Error fetching week progress:', error);
      return reply.status(500).send({ error: 'Failed to fetch week progress' });
    }
  });

  // Get monthly progress (last 12 weeks)
  fastify.get('/api/progress/monthly', { preHandler: authMiddleware }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const userId = request.user!.userId;

      const profile = await db.findUserProfileByUserId(userId);
      if (!profile) {
        return reply.status(404).send({ error: 'Profile not set up', needsSetup: true });
      }

      // Get the last 12 weekly summaries
      const weeks = await db.findWeeklySummariesByUser(userId, 12);

      // Calculate overall stats
      const totalWeeks = weeks.length;
      const avgComplianceRate = totalWeeks > 0
        ? weeks.reduce((sum, w) => sum + w.complianceRate, 0) / totalWeeks
        : 0;

      // Calculate trends (compare last 4 weeks to previous 4 weeks)
      let trend = 'stable';
      if (weeks.length >= 8) {
        const recent = weeks.slice(0, 4);
        const previous = weeks.slice(4, 8);
        const recentAvg = recent.reduce((sum, w) => sum + w.complianceRate, 0) / 4;
        const previousAvg = previous.reduce((sum, w) => sum + w.complianceRate, 0) / 4;

        if (recentAvg > previousAvg + 0.1) trend = 'improving';
        else if (recentAvg < previousAvg - 0.1) trend = 'declining';
      }

      // Format weeks with proper date strings
      const formattedWeeks = weeks.map(w => ({
        ...w,
        weekStart: typeof w.weekStart === 'string' ? w.weekStart : (w.weekStart as Date).toISOString().split('T')[0],
        weekEnd: typeof w.weekEnd === 'string' ? w.weekEnd : (w.weekEnd as Date).toISOString().split('T')[0]
      }));

      return {
        weeks: formattedWeeks,
        summary: {
          totalWeeks,
          avgComplianceRate,
          trend
        },
        dietType: profile.dietType
      };
    } catch (error) {
      console.error('Error fetching monthly progress:', error);
      return reply.status(500).send({ error: 'Failed to fetch monthly progress' });
    }
  });

  // Get progress for a specific date range
  fastify.get<{ Querystring: { start: string; end: string } }>('/api/progress/range', { preHandler: authMiddleware }, async (
    request,
    reply
  ) => {
    const userId = request.user!.userId;

    const { start, end } = request.query;
    if (!start || !end) {
      return reply.status(400).send({ error: 'Start and end dates required' });
    }

    const startDate = new Date(start);
    const endDate = new Date(end);

    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      return reply.status(400).send({ error: 'Invalid date format' });
    }

    const days = await getProgressRange(userId, startDate, endDate);

    return { days };
  });
}

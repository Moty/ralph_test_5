import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authMiddleware } from '../middleware/auth.js';
import { getDb } from '../services/database.js';
import { DIET_TEMPLATES, calculateMacroCompliance } from '../services/dietCompliance.js';

interface NutritionData {
  totals: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
    fiber?: number;
    sugar?: number;
  };
}

export async function userRoutes(server: FastifyInstance) {
  const db = getDb();
  
  server.get(
    '/api/user/stats',
    { preHandler: authMiddleware },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const userId = request.user!.userId;
        server.log.info({ userId }, 'Fetching user stats');

        // Get current date boundaries
        const now = new Date();
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        
        // Get week start (Sunday)
        const weekStart = new Date(todayStart);
        weekStart.setDate(weekStart.getDate() - weekStart.getDay());

        // Fetch all user's meal analyses
        const allMeals = await db.findMealAnalysesByUserId(userId);
        server.log.info({ userId, mealCount: allMeals.length }, 'Fetched user meals');

        // Filter meals by time periods
        const todayMeals = allMeals.filter(
          (meal) => meal.createdAt >= todayStart
        );
        const weekMeals = allMeals.filter(
          (meal) => meal.createdAt >= weekStart
        );

        // Calculate stats for each period
        const calculateStats = (meals: typeof allMeals) => {
          if (meals.length === 0) {
            return {
              count: 0,
              avgCalories: 0,
              totalCalories: 0,
              totalProtein: 0,
              totalCarbs: 0,
              totalFat: 0,
            };
          }

          const totals = meals.reduce(
            (acc, meal) => {
              const data = meal.nutritionData as unknown as NutritionData;
              return {
                calories: acc.calories + data.totals.calories,
                protein: acc.protein + data.totals.protein,
                carbs: acc.carbs + data.totals.carbs,
                fat: acc.fat + data.totals.fat,
              };
            },
            { calories: 0, protein: 0, carbs: 0, fat: 0 }
          );

          return {
            count: meals.length,
            avgCalories: Math.round(totals.calories / meals.length),
            totalCalories: Math.round(totals.calories),
            totalProtein: Math.round(totals.protein),
            totalCarbs: Math.round(totals.carbs),
            totalFat: Math.round(totals.fat),
          };
        };

        const todayStats = calculateStats(todayMeals);
        const stats = {
          today: todayStats,
          week: calculateStats(weekMeals),
          allTime: calculateStats(allMeals),
        };

        // Get user profile for diet info
        const profile = await db.findUserProfileByUserId(userId);

        // If user has a profile, add diet goals and compliance
        let dietInfo = null;
        if (profile) {
          const template = DIET_TEMPLATES[profile.dietType] || DIET_TEMPLATES.balanced;

          // Calculate today's compliance
          const todayCompliance = calculateMacroCompliance(
            {
              calories: todayStats.totalCalories,
              protein: todayStats.totalProtein,
              carbs: todayStats.totalCarbs,
              fat: todayStats.totalFat
            },
            {
              calories: profile.dailyCalorieGoal,
              protein: profile.dailyProteinGoal,
              carbs: profile.dailyCarbsGoal,
              fat: profile.dailyFatGoal
            },
            template
          );

          dietInfo = {
            dietType: profile.dietType,
            dietName: template.name,
            goals: {
              dailyCalories: profile.dailyCalorieGoal,
              dailyProtein: profile.dailyProteinGoal,
              dailyCarbs: profile.dailyCarbsGoal,
              dailyFat: profile.dailyFatGoal,
              dailyFiber: profile.dailyFiberGoal,
              dailySugarLimit: profile.dailySugarLimit
            },
            todayCompliance: {
              isOnTrack: todayCompliance.isOnTrack,
              carbsCompliance: todayCompliance.carbsCompliance,
              proteinCompliance: todayCompliance.proteinCompliance,
              fatCompliance: todayCompliance.fatCompliance,
              overallCompliance: todayCompliance.overallCompliance,
              issues: todayCompliance.issues,
              suggestions: todayCompliance.suggestions
            }
          };
        }

        return reply.code(200).send({
          ...stats,
          dietInfo,
          hasProfile: !!profile
        });
      } catch (error) {
        server.log.error({ error, userId: request.user?.userId }, 'Error fetching user stats');
        return reply.code(500).send({ error: 'Failed to fetch user stats' });
      }
    }
  );
}

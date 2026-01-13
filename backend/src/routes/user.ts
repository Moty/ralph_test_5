import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authMiddleware } from '../middleware/auth.js';
import { getDb } from '../services/database.js';

interface NutritionData {
  totals: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
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

        // Get current date boundaries
        const now = new Date();
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        
        // Get week start (Sunday)
        const weekStart = new Date(todayStart);
        weekStart.setDate(weekStart.getDate() - weekStart.getDay());

        // Fetch all user's meal analyses
        const allMeals = await db.findMealAnalysesByUserId(userId);

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

        const stats = {
          today: calculateStats(todayMeals),
          week: calculateStats(weekMeals),
          allTime: calculateStats(allMeals),
        };

        return reply.code(200).send(stats);
      } catch (error) {
        server.log.error(error);
        return reply.code(500).send({ error: 'Failed to fetch user stats' });
      }
    }
  );
}

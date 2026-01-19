import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authMiddleware } from '../middleware/auth.js';
import { getDb } from '../services/database.js';

interface MealResponse {
  id: string;
  thumbnail: string | null;
  foods: Array<{
    name: string;
    portion: string;
    nutrition: {
      calories: number;
      protein: number;
      carbs: number;
      fat: number;
    };
    confidence: number;
  }>;
  totals: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
  timestamp: string;
}

export async function mealsRoutes(server: FastifyInstance) {
  const db = getDb();
  
  // Get all meals for the authenticated user
  server.get('/api/meals', { preHandler: authMiddleware }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const userId = request.user!.userId;
      console.log(`[Meals] Fetching meals for user: ${userId}`);
      
      const mealAnalyses = await db.findMealAnalysesByUserId(userId);
      console.log(`[Meals] Found ${mealAnalyses.length} meals`);
      
      // Transform to response format
      const meals: MealResponse[] = mealAnalyses.map(analysis => {
        const nutritionData = analysis.nutritionData as any;
        return {
          id: analysis.id,
          thumbnail: analysis.thumbnail,
          foods: nutritionData.foods || [],
          totals: nutritionData.totals || { calories: 0, protein: 0, carbs: 0, fat: 0 },
          timestamp: analysis.createdAt.toISOString()
        };
      });
      
      return reply.code(200).send({ meals });
      
    } catch (error) {
      server.log.error(error);
      return reply.code(500).send({ error: 'Failed to fetch meals' });
    }
  });
  
  // Get a single meal by ID
  server.get<{ Params: { id: string } }>('/api/meals/:id', { preHandler: authMiddleware }, async (request, reply) => {
    try {
      const { id } = request.params;
      const userId = request.user!.userId;
      
      const analysis = await db.findMealAnalysisById(id);
      
      if (!analysis) {
        return reply.code(404).send({ error: 'Meal not found' });
      }
      
      // Verify ownership
      if (analysis.userId !== userId) {
        return reply.code(403).send({ error: 'Access denied' });
      }
      
      const nutritionData = analysis.nutritionData as any;
      const meal: MealResponse = {
        id: analysis.id,
        thumbnail: analysis.thumbnail,
        foods: nutritionData.foods || [],
        totals: nutritionData.totals || { calories: 0, protein: 0, carbs: 0, fat: 0 },
        timestamp: analysis.createdAt.toISOString()
      };
      
      return reply.code(200).send(meal);
      
    } catch (error) {
      server.log.error(error);
      return reply.code(500).send({ error: 'Failed to fetch meal' });
    }
  });
}

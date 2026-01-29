import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { getDb } from '../services/database.js';
import { DIET_TEMPLATES, calculateRecommendedGoals } from '../services/dietCompliance.js';
import { authMiddleware } from '../middleware/auth.js';

interface ProfileBody {
  dietType?: string;
  dailyCalorieGoal?: number;
  dailyProteinGoal?: number;
  dailyCarbsGoal?: number;
  dailyFatGoal?: number;
  dailyFiberGoal?: number;
  dailySugarLimit?: number;
  weight?: number;
  height?: number;
  age?: number;
  gender?: 'male' | 'female';
  activityLevel?: 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';
  dietaryRestrictions?: string[];
}

export default async function profileRoutes(fastify: FastifyInstance) {
  const db = getDb();

  // Get user profile
  fastify.get('/api/profile', { preHandler: authMiddleware }, async (request: FastifyRequest, reply: FastifyReply) => {
    const userId = request.user!.userId;

    const profile = await db.findUserProfileByUserId(userId);

    if (!profile) {
      return reply.status(404).send({ error: 'Profile not found', needsSetup: true });
    }

    // Get the diet template for reference
    const template = DIET_TEMPLATES[profile.dietType] || DIET_TEMPLATES.balanced;

    return {
      profile,
      template: {
        name: template.name,
        description: template.description,
        proteinRatio: template.proteinRatio,
        carbsRatio: template.carbsRatio,
        fatRatio: template.fatRatio
      }
    };
  });

  // Create or update user profile
  fastify.post<{ Body: ProfileBody }>('/api/profile', { preHandler: authMiddleware }, async (request, reply) => {
    const userId = request.user!.userId;

    const body = request.body;
    const existingProfile = await db.findUserProfileByUserId(userId);

    // Get diet template for default values
    const dietType = body.dietType || existingProfile?.dietType || 'balanced';
    const template = DIET_TEMPLATES[dietType] || DIET_TEMPLATES.balanced;

    // Calculate goals if physical metrics provided
    let calculatedGoals = null;
    if (body.weight && body.height && body.age && body.gender && body.activityLevel) {
      calculatedGoals = calculateRecommendedGoals(
        body.weight,
        body.height,
        body.age,
        body.gender,
        body.activityLevel,
        template
      );
    }

    const profileData = {
      userId,
      dietType,
      dailyCalorieGoal: body.dailyCalorieGoal ?? calculatedGoals?.calories ?? existingProfile?.dailyCalorieGoal ?? template.baselineCalories,
      dailyProteinGoal: body.dailyProteinGoal ?? calculatedGoals?.protein ?? existingProfile?.dailyProteinGoal ?? template.baselineProtein,
      dailyCarbsGoal: body.dailyCarbsGoal ?? calculatedGoals?.carbs ?? existingProfile?.dailyCarbsGoal ?? template.baselineCarbs,
      dailyFatGoal: body.dailyFatGoal ?? calculatedGoals?.fat ?? existingProfile?.dailyFatGoal ?? template.baselineFat,
      dailyFiberGoal: body.dailyFiberGoal ?? existingProfile?.dailyFiberGoal ?? template.fiberMinimum ?? null,
      dailySugarLimit: body.dailySugarLimit ?? existingProfile?.dailySugarLimit ?? template.sugarMaximum ?? null,
      weight: body.weight ?? existingProfile?.weight ?? null,
      height: body.height ?? existingProfile?.height ?? null,
      age: body.age ?? existingProfile?.age ?? null,
      gender: body.gender ?? existingProfile?.gender ?? null,
      activityLevel: body.activityLevel ?? existingProfile?.activityLevel ?? null,
      dietaryRestrictions: body.dietaryRestrictions ?? existingProfile?.dietaryRestrictions ?? []
    };

    let profile;
    if (existingProfile) {
      profile = await db.updateUserProfile(userId, profileData);
    } else {
      profile = await db.createUserProfile(profileData);
    }

    return {
      profile,
      template: {
        name: template.name,
        description: template.description
      }
    };
  });

  // Get all diet templates
  fastify.get('/api/diet-templates', async (_request: FastifyRequest, _reply: FastifyReply) => {
    // Return the templates from our in-memory definitions (faster than DB)
    const templates = Object.values(DIET_TEMPLATES).map(t => ({
      dietType: t.dietType,
      name: t.name,
      description: t.description,
      proteinRatio: t.proteinRatio,
      carbsRatio: t.carbsRatio,
      fatRatio: t.fatRatio,
      baselineCalories: t.baselineCalories,
      baselineProtein: t.baselineProtein,
      baselineCarbs: t.baselineCarbs,
      baselineFat: t.baselineFat,
      fiberMinimum: t.fiberMinimum,
      sugarMaximum: t.sugarMaximum
    }));

    return { templates };
  });

  // Calculate recommended goals based on user metrics
  fastify.post('/api/profile/calculate-goals', async (
    request: FastifyRequest<{
      Body: {
        weight: number;
        height: number;
        age: number;
        gender: 'male' | 'female';
        activityLevel: 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';
        dietType: string;
      }
    }>,
    reply: FastifyReply
  ) => {
    const { weight, height, age, gender, activityLevel, dietType } = request.body;

    if (!weight || !height || !age || !gender || !activityLevel || !dietType) {
      return reply.status(400).send({ error: 'All fields are required' });
    }

    const template = DIET_TEMPLATES[dietType] || DIET_TEMPLATES.balanced;
    const goals = calculateRecommendedGoals(weight, height, age, gender, activityLevel, template);

    return {
      goals,
      template: {
        name: template.name,
        description: template.description
      }
    };
  });
}

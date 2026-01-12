import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { initializeModel, createNutritionPrompt } from '../services/gemini.js';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import pg from 'pg';
import { Buffer } from 'buffer';

// Initialize PrismaClient with PostgreSQL adapter for Prisma 7
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

interface AnalyzeResponse {
  id?: string;
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

export async function analyzeRoutes(server: FastifyInstance) {
  server.post('/api/analyze', async (request: FastifyRequest, reply: FastifyReply) => {
    const timeout = setTimeout(() => {
      if (!reply.sent) {
        reply.code(408).send({ error: 'Request timeout - analysis took too long' });
      }
    }, 30000);

    try {
      console.log('Starting multipart parsing...');
      
      // Parse multipart form data - collect all parts
      const parts = request.parts();
      let buffer: Buffer | null = null;
      let mimetype: string = '';
      let modelName: string | undefined;
      
      for await (const part of parts) {
        console.log('Processing part:', part.fieldname, part.type);
        
        if (part.type === 'file' && part.fieldname === 'image') {
          // Read buffer immediately while stream is open
          mimetype = part.mimetype;
          buffer = await part.toBuffer();
          console.log('Image buffer size:', buffer.length);
        } else if (part.type === 'field' && part.fieldname === 'model') {
          modelName = part.value as string;
          console.log('Model from request:', modelName);
        }
      }
      
      console.log('Parsing complete. Has buffer:', !!buffer, 'Model:', modelName);
      
      if (!buffer) {
        clearTimeout(timeout);
        return reply.code(400).send({ error: 'No image file provided' });
      }

      // Validate file type
      const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png'];
      if (!allowedMimeTypes.includes(mimetype)) {
        clearTimeout(timeout);
        return reply.code(400).send({ 
          error: 'Invalid file format. Only JPG and PNG images are allowed' 
        });
      }

      // Validate file size (max 5MB)
      const maxSize = 5 * 1024 * 1024; // 5MB in bytes
      if (buffer.length > maxSize) {
        clearTimeout(timeout);
        return reply.code(400).send({ 
          error: 'File too large. Maximum size is 5MB' 
        });
      }

      // Initialize Gemini model (use client-provided model if available)
      const model = initializeModel(modelName);

      // Prepare image for Gemini
      const imagePart = {
        inlineData: {
          data: buffer.toString('base64'),
          mimeType: mimetype
        }
      };

      // Generate content with Gemini
      console.log('Calling Gemini with model:', modelName || 'default');
      const prompt = createNutritionPrompt();
      const result = await model.generateContent([prompt, imagePart]);
      const response = result.response;
      const text = response.text();

      // Parse JSON response
      let nutritionData: AnalyzeResponse;
      try {
        // Remove markdown code blocks if present
        const cleanText = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
        nutritionData = JSON.parse(cleanText);
      } catch (parseError) {
        clearTimeout(timeout);
        server.log.error({ parseError, responseText: text }, 'Failed to parse Gemini response');
        return reply.code(500).send({ 
          error: 'Failed to analyze image - unable to parse nutrition data' 
        });
      }

      // Validate response structure
      if (!nutritionData.foods || !nutritionData.totals) {
        clearTimeout(timeout);
        return reply.code(500).send({ 
          error: 'Invalid response from analysis service' 
        });
      }

      // Save to database
      let savedAnalysis;
      try {
        savedAnalysis = await prisma.mealAnalysis.create({
          data: {
            userId: 'placeholder-user-id',
            imageUrl: '',
            nutritionData: nutritionData as any,
          },
        });
      } catch (dbError) {
        server.log.error({ dbError }, 'Failed to save analysis to database');
        // Continue and return the analysis even if database save fails
      }

      // Add analysis ID to response if saved
      const responseData: AnalyzeResponse = {
        ...nutritionData,
        timestamp: new Date().toISOString(),
        ...(savedAnalysis && { id: savedAnalysis.id }),
      };

      console.log('Analysis complete, returning response');
      clearTimeout(timeout);
      return reply.code(200).send(responseData);

    } catch (error) {
      clearTimeout(timeout);
      server.log.error(error);
      
      if (error instanceof Error) {
        return reply.code(500).send({ 
          error: 'Analysis failed - please try again' 
        });
      }
      
      return reply.code(500).send({ 
        error: 'An unexpected error occurred' 
      });
    }
  });
}

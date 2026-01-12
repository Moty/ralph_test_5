import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { initializeModel, createNutritionPrompt } from '../services/gemini.js';
import { Buffer } from 'buffer';

interface AnalyzeResponse {
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
}

export async function analyzeRoutes(server: FastifyInstance) {
  server.post('/api/analyze', async (request: FastifyRequest, reply: FastifyReply) => {
    const timeout = setTimeout(() => {
      if (!reply.sent) {
        reply.code(408).send({ error: 'Request timeout - analysis took too long' });
      }
    }, 30000);

    try {
      let data;
      try {
        data = await request.file();
      } catch (err) {
        clearTimeout(timeout);
        return reply.code(400).send({ error: 'No image file provided' });
      }
      
      if (!data) {
        clearTimeout(timeout);
        return reply.code(400).send({ error: 'No image file provided' });
      }

      // Validate file type
      const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png'];
      if (!allowedMimeTypes.includes(data.mimetype)) {
        clearTimeout(timeout);
        return reply.code(400).send({ 
          error: 'Invalid file format. Only JPG and PNG images are allowed' 
        });
      }

      // Read file buffer
      const buffer = await data.toBuffer();

      // Validate file size (max 5MB)
      const maxSize = 5 * 1024 * 1024; // 5MB in bytes
      if (buffer.length > maxSize) {
        clearTimeout(timeout);
        return reply.code(400).send({ 
          error: 'File too large. Maximum size is 5MB' 
        });
      }

      // Initialize Gemini model
      const model = initializeModel();

      // Prepare image for Gemini
      const imagePart = {
        inlineData: {
          data: buffer.toString('base64'),
          mimeType: data.mimetype
        }
      };

      // Generate content with Gemini
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

      clearTimeout(timeout);
      return reply.code(200).send(nutritionData);

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

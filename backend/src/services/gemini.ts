import { GoogleGenerativeAI } from '@google/generative-ai';

let genAI: GoogleGenerativeAI | null = null;

export function initializeModel(modelName?: string) {
  const apiKey = process.env.GEMINI_API_KEY;
  
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY environment variable is required');
  }
  
  // Use provided model, fall back to env var, then default
  const model = modelName || process.env.GEMINI_MODEL || 'gemini-2.5-flash';
  
  try {
    genAI = new GoogleGenerativeAI(apiKey);
    return genAI.getGenerativeModel({ model });
  } catch (error) {
    throw new Error(`Failed to initialize Gemini: ${error instanceof Error ? error.message : String(error)}`);
  }
}

export function getGenAI() {
  if (!genAI) {
    throw new Error('Gemini not initialized. Call initializeModel() first.');
  }
  return genAI;
}

/**
 * Creates a nutrition analysis prompt for Gemini AI.
 * 
 * This prompt instructs Gemini to:
 * 1. Identify all food items in the image
 * 2. Estimate portion sizes in common units (oz, g, cups, pieces, etc.)
 * 3. Calculate macronutrient breakdown (calories, protein, carbs, fat) for each item
 * 4. Provide total nutritional values
 * 5. Include confidence scores (0-1 range) for each food identification
 * 
 * The response format matches the NutritionData schema and includes:
 * - foods: array of {name, portion, nutrition, confidence}
 * - totals: aggregated {calories, protein, carbs, fat}
 * 
 * @returns The formatted prompt string for Gemini API
 */
export function createNutritionPrompt(): string {
  return `Analyze this food image and provide detailed nutritional information.

Instructions:
1. Identify all food items visible in the image
2. Estimate portion size for each item using common units (oz, g, cups, pieces, slices, tbsp, etc.)
3. Calculate nutritional values for each food item:
   - Calories (kcal)
   - Protein (grams)
   - Carbohydrates (grams)
   - Fat (grams)
   - Fiber (grams) - dietary fiber content
   - Sugar (grams) - total sugars content
4. Provide a confidence score (0.0 to 1.0) for each food identification
5. Calculate total nutritional values across all items

Return ONLY valid JSON matching this exact schema:
{
  "foods": [
    {
      "name": "food item name",
      "portion": "portion size with unit",
      "nutrition": {
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number,
        "fiber": number,
        "sugar": number
      },
      "confidence": number (0.0-1.0)
    }
  ],
  "totals": {
    "calories": number,
    "protein": number,
    "carbs": number,
    "fat": number,
    "fiber": number,
    "sugar": number
  }
}

Important:
- Use standard USDA nutritional data when available
- If unsure about exact portion, provide best estimate and lower confidence score
- All numeric values should be numbers, not strings
- Confidence below 0.5 indicates high uncertainty
- Fiber is important for calculating net carbs (carbs - fiber) for low-carb diets
- Sugar should be the total sugars content, not added sugars
- Do not include any text outside the JSON response`;
}

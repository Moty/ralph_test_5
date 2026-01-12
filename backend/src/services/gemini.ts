import { GoogleGenerativeAI } from '@google/generative-ai';

let genAI: GoogleGenerativeAI | null = null;

export function initializeModel() {
  const apiKey = process.env.GEMINI_API_KEY;
  
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY environment variable is required');
  }
  
  try {
    genAI = new GoogleGenerativeAI(apiKey);
    return genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
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

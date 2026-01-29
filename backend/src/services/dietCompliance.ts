/**
 * Diet Compliance Service
 * Handles diet-specific compliance calculations and recommendations
 */

export interface DietTemplate {
  dietType: string;
  name: string;
  description: string;
  proteinRatio: number;
  carbsRatio: number;
  fatRatio: number;
  baselineCalories: number;
  baselineProtein: number;
  baselineCarbs: number;
  baselineFat: number;
  carbsTolerance: number;
  proteinTolerance: number;
  fatTolerance: number;
  fiberMinimum?: number;
  sugarMaximum?: number;
}

export interface MacroGoals {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber?: number;
  sugar?: number;
}

export interface MacroActuals {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber?: number;
  sugar?: number;
}

export interface ComplianceResult {
  isOnTrack: boolean;
  carbsCompliance: number;    // 0-1, where 1 is perfect compliance
  proteinCompliance: number;
  fatCompliance: number;
  caloriesCompliance: number;
  overallCompliance: number;
  issues: string[];
  suggestions: string[];
}

// Diet template definitions
export const DIET_TEMPLATES: Record<string, DietTemplate> = {
  keto: {
    dietType: 'keto',
    name: 'Ketogenic',
    description: 'High fat, very low carb diet to achieve ketosis. Ideal for weight loss and blood sugar control.',
    proteinRatio: 25,
    carbsRatio: 5,
    fatRatio: 70,
    baselineCalories: 2000,
    baselineProtein: 125,
    baselineCarbs: 25,
    baselineFat: 156,
    carbsTolerance: 20,    // Strict on carbs
    proteinTolerance: 30,
    fatTolerance: 30,
    fiberMinimum: 20,      // Important for gut health on keto
    sugarMaximum: 10       // Very strict on sugar
  },
  paleo: {
    dietType: 'paleo',
    name: 'Paleo',
    description: 'Based on foods similar to those eaten during the Paleolithic era. Focus on whole foods.',
    proteinRatio: 30,
    carbsRatio: 40,
    fatRatio: 30,
    baselineCalories: 2000,
    baselineProtein: 150,
    baselineCarbs: 200,
    baselineFat: 67,
    carbsTolerance: 30,
    proteinTolerance: 25,
    fatTolerance: 30,
    fiberMinimum: 30,
    sugarMaximum: 30       // No added sugars, but natural sugars ok
  },
  vegan: {
    dietType: 'vegan',
    name: 'Vegan',
    description: 'Plant-based diet excluding all animal products. Focus on protein from legumes, nuts, and grains.',
    proteinRatio: 15,
    carbsRatio: 55,
    fatRatio: 30,
    baselineCalories: 2000,
    baselineProtein: 75,
    baselineCarbs: 275,
    baselineFat: 67,
    carbsTolerance: 35,
    proteinTolerance: 30,  // More flexible on protein since plant-based is harder
    fatTolerance: 30,
    fiberMinimum: 35,      // High fiber typical of vegan diet
    sugarMaximum: 50
  },
  mediterranean: {
    dietType: 'mediterranean',
    name: 'Mediterranean',
    description: 'Heart-healthy diet rich in olive oil, fish, vegetables, and whole grains.',
    proteinRatio: 20,
    carbsRatio: 40,
    fatRatio: 40,
    baselineCalories: 2000,
    baselineProtein: 100,
    baselineCarbs: 200,
    baselineFat: 89,
    carbsTolerance: 30,
    proteinTolerance: 30,
    fatTolerance: 30,
    fiberMinimum: 30,
    sugarMaximum: 40
  },
  lowcarb: {
    dietType: 'lowcarb',
    name: 'Low-Carb',
    description: 'Moderate carb restriction for weight management. More flexible than keto.',
    proteinRatio: 30,
    carbsRatio: 20,
    fatRatio: 50,
    baselineCalories: 2000,
    baselineProtein: 150,
    baselineCarbs: 100,
    baselineFat: 111,
    carbsTolerance: 25,
    proteinTolerance: 30,
    fatTolerance: 30,
    fiberMinimum: 25,
    sugarMaximum: 25
  },
  balanced: {
    dietType: 'balanced',
    name: 'Balanced',
    description: 'Standard balanced diet following general nutritional guidelines.',
    proteinRatio: 20,
    carbsRatio: 50,
    fatRatio: 30,
    baselineCalories: 2000,
    baselineProtein: 100,
    baselineCarbs: 250,
    baselineFat: 67,
    carbsTolerance: 35,
    proteinTolerance: 35,
    fatTolerance: 35,
    fiberMinimum: 25,
    sugarMaximum: 50
  }
};

/**
 * Calculate macro compliance based on current intake vs goals
 */
export function calculateMacroCompliance(
  actual: MacroActuals,
  goals: MacroGoals,
  template: DietTemplate
): ComplianceResult {
  const issues: string[] = [];
  const suggestions: string[] = [];

  // Calculate individual compliance scores (1 = perfect, 0 = way off)
  const caloriesCompliance = calculateSingleCompliance(actual.calories, goals.calories, 20);
  const proteinCompliance = calculateSingleCompliance(actual.protein, goals.protein, template.proteinTolerance);
  const carbsCompliance = calculateSingleCompliance(actual.carbs, goals.carbs, template.carbsTolerance);
  const fatCompliance = calculateSingleCompliance(actual.fat, goals.fat, template.fatTolerance);

  // Check for issues
  if (actual.carbs > goals.carbs * (1 + template.carbsTolerance / 100)) {
    issues.push(`Carbs are ${Math.round(((actual.carbs / goals.carbs) - 1) * 100)}% over your goal`);
    if (template.dietType === 'keto') {
      suggestions.push('Consider reducing carbs to stay in ketosis');
    } else {
      suggestions.push('Try swapping some carbs for vegetables or protein');
    }
  }

  if (actual.protein < goals.protein * (1 - template.proteinTolerance / 100)) {
    issues.push(`Protein is ${Math.round((1 - actual.protein / goals.protein) * 100)}% under your goal`);
    suggestions.push('Add lean protein like chicken, fish, eggs, or legumes');
  }

  if (actual.fat > goals.fat * (1 + template.fatTolerance / 100) && template.dietType !== 'keto') {
    issues.push(`Fat is ${Math.round(((actual.fat / goals.fat) - 1) * 100)}% over your goal`);
    suggestions.push('Consider reducing cooking oils and fatty meats');
  }

  // Special handling for keto - check if under fat goal
  if (template.dietType === 'keto' && actual.fat < goals.fat * 0.7) {
    issues.push('Fat intake is low for keto');
    suggestions.push('Add healthy fats like avocado, olive oil, or nuts');
  }

  // Check fiber and sugar if available
  if (actual.fiber !== undefined && template.fiberMinimum !== undefined) {
    if (actual.fiber < template.fiberMinimum * 0.7) {
      issues.push('Fiber intake is low');
      suggestions.push('Add more vegetables, legumes, or whole grains');
    }
  }

  if (actual.sugar !== undefined && template.sugarMaximum !== undefined) {
    if (actual.sugar > template.sugarMaximum) {
      issues.push(`Sugar is over your ${template.sugarMaximum}g limit`);
      suggestions.push('Reduce sweets, fruits, or sweetened beverages');
    }
  }

  // Calculate overall compliance (weighted average)
  const overallCompliance = (
    caloriesCompliance * 0.25 +
    proteinCompliance * 0.25 +
    carbsCompliance * 0.3 +  // Slightly higher weight for carbs
    fatCompliance * 0.2
  );

  // On track if overall compliance is above 70%
  const isOnTrack = overallCompliance >= 0.7 && issues.length === 0;

  return {
    isOnTrack,
    carbsCompliance,
    proteinCompliance,
    fatCompliance,
    caloriesCompliance,
    overallCompliance,
    issues,
    suggestions
  };
}

/**
 * Calculate compliance for a single macro (0-1 scale)
 */
function calculateSingleCompliance(actual: number, goal: number, tolerancePercent: number): number {
  if (goal === 0) return actual === 0 ? 1 : 0;

  const ratio = actual / goal;
  const lowerBound = 1 - tolerancePercent / 100;
  const upperBound = 1 + tolerancePercent / 100;

  if (ratio >= lowerBound && ratio <= upperBound) {
    return 1;
  }

  // Calculate how far off we are
  if (ratio < lowerBound) {
    return Math.max(0, ratio / lowerBound);
  } else {
    return Math.max(0, 1 - (ratio - upperBound) / upperBound);
  }
}

/**
 * Calculate recommended macro goals based on user profile
 * Uses Harris-Benedict equation for BMR and adjusts for activity level
 */
export function calculateRecommendedGoals(
  weight: number,      // kg
  height: number,      // cm
  age: number,
  gender: 'male' | 'female',
  activityLevel: 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active',
  template: DietTemplate
): MacroGoals {
  // Calculate BMR using Harris-Benedict equation
  let bmr: number;
  if (gender === 'male') {
    bmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
  } else {
    bmr = 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
  }

  // Apply activity multiplier
  const activityMultipliers: Record<string, number> = {
    sedentary: 1.2,
    light: 1.375,
    moderate: 1.55,
    active: 1.725,
    very_active: 1.9
  };

  const tdee = Math.round(bmr * (activityMultipliers[activityLevel] || 1.55));

  // Calculate macros based on diet ratios
  const protein = Math.round((tdee * template.proteinRatio / 100) / 4); // 4 cal per gram
  const carbs = Math.round((tdee * template.carbsRatio / 100) / 4);     // 4 cal per gram
  const fat = Math.round((tdee * template.fatRatio / 100) / 9);         // 9 cal per gram

  return {
    calories: tdee,
    protein,
    carbs,
    fat,
    fiber: template.fiberMinimum,
    sugar: template.sugarMaximum
  };
}

/**
 * Generate meal suggestions based on remaining daily budget
 */
export function getNextMealSuggestions(
  remainingCalories: number,
  remainingProtein: number,
  remainingCarbs: number,
  remainingFat: number,
  dietType: string
): string[] {
  const suggestions: string[] = [];
  const template = DIET_TEMPLATES[dietType] || DIET_TEMPLATES.balanced;

  // If over budget
  if (remainingCalories < 0) {
    suggestions.push('You\'ve exceeded your daily calorie goal. Consider a light dinner or skip the snack.');
    return suggestions;
  }

  // Low remaining budget
  if (remainingCalories < 200) {
    suggestions.push('You have a small calorie budget left. Consider a light snack like vegetables or a small portion of nuts.');
    return suggestions;
  }

  // Specific diet suggestions
  if (dietType === 'keto') {
    if (remainingCarbs > 10) {
      suggestions.push('You have some carb allowance left - consider some low-carb vegetables');
    }
    if (remainingFat > 30) {
      suggestions.push('Add healthy fats: avocado, olive oil, or fatty fish');
    }
    if (remainingProtein > 20) {
      suggestions.push('Good protein options: eggs, chicken, or beef');
    }
  } else if (dietType === 'vegan') {
    if (remainingProtein > 15) {
      suggestions.push('Boost protein with: tofu, tempeh, legumes, or seitan');
    }
    suggestions.push('Consider a nutrient-dense meal with quinoa and vegetables');
  } else if (dietType === 'paleo') {
    suggestions.push('Try grilled meat with roasted vegetables');
    if (remainingCarbs > 30) {
      suggestions.push('Sweet potatoes or fruits would fit your remaining carbs');
    }
  } else {
    // Balanced/other
    if (remainingProtein > remainingCarbs && remainingProtein > remainingFat) {
      suggestions.push('Focus on protein: lean meat, fish, eggs, or Greek yogurt');
    } else if (remainingCarbs > remainingProtein && remainingCarbs > remainingFat) {
      suggestions.push('Good carb options: whole grains, fruits, or starchy vegetables');
    } else {
      suggestions.push('A balanced meal with protein, veggies, and complex carbs would be ideal');
    }
  }

  return suggestions;
}

/**
 * Check if user is in ketosis based on ketone level
 * @param ketoneLevel Blood ketone level in mmol/L
 */
export function isInKetosis(ketoneLevel: number): { inKetosis: boolean; level: string } {
  if (ketoneLevel < 0.5) {
    return { inKetosis: false, level: 'none' };
  } else if (ketoneLevel < 1.0) {
    return { inKetosis: true, level: 'light' };
  } else if (ketoneLevel < 3.0) {
    return { inKetosis: true, level: 'optimal' };
  } else {
    return { inKetosis: true, level: 'high' };  // May indicate need for caution
  }
}

/**
 * Calculate net carbs (important for keto)
 */
export function calculateNetCarbs(totalCarbs: number, fiber: number): number {
  return Math.max(0, totalCarbs - fiber);
}

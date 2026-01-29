import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const dietTemplates = [
  {
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
    carbsTolerance: 20,
    proteinTolerance: 30,
    fatTolerance: 30,
    fiberMinimum: 20,
    sugarMaximum: 10
  },
  {
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
    sugarMaximum: 30
  },
  {
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
    proteinTolerance: 30,
    fatTolerance: 30,
    fiberMinimum: 35,
    sugarMaximum: 50
  },
  {
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
  {
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
  {
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
];

async function main() {
  console.log('Seeding diet templates...');

  for (const template of dietTemplates) {
    await prisma.dietTemplate.upsert({
      where: { dietType: template.dietType },
      update: template,
      create: template
    });
    console.log(`  ✓ ${template.name} (${template.dietType})`);
  }

  console.log('Seeding complete!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

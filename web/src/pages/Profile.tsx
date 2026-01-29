import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, SectionHeader, Button } from '../components/ui';
import { profileApi } from '../services/api';
import type {
  DietTemplate,
  UserProfile,
  ProfileUpdateData,
  CalculateGoalsResponse,
  ApiError
} from '../services/api';

type Step = 'diet' | 'metrics' | 'goals' | 'complete';

export default function Profile() {
  const navigate = useNavigate();
  const [step, setStep] = useState<Step>('diet');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Diet templates
  const [templates, setTemplates] = useState<DietTemplate[]>([]);

  // Existing profile
  const [existingProfile, setExistingProfile] = useState<UserProfile | null>(null);

  // Form data
  const [dietType, setDietType] = useState('balanced');
  const [weight, setWeight] = useState<number | ''>('');
  const [height, setHeight] = useState<number | ''>('');
  const [age, setAge] = useState<number | ''>('');
  const [gender, setGender] = useState<'male' | 'female'>('male');
  const [activityLevel, setActivityLevel] = useState<'sedentary' | 'light' | 'moderate' | 'active' | 'very_active'>('moderate');

  // Goals (can be calculated or manual)
  const [dailyCalorieGoal, setDailyCalorieGoal] = useState<number>(2000);
  const [dailyProteinGoal, setDailyProteinGoal] = useState<number>(100);
  const [dailyCarbsGoal, setDailyCarbsGoal] = useState<number>(250);
  const [dailyFatGoal, setDailyFatGoal] = useState<number>(67);
  const [calculatedGoals, setCalculatedGoals] = useState<CalculateGoalsResponse | null>(null);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    setError(null);

    try {
      // Load diet templates
      const { templates: loadedTemplates } = await profileApi.getDietTemplates();
      setTemplates(loadedTemplates);

      // Try to load existing profile
      try {
        const { profile } = await profileApi.getProfile();
        setExistingProfile(profile);
        setDietType(profile.dietType);
        if (profile.weight) setWeight(profile.weight);
        if (profile.height) setHeight(profile.height);
        if (profile.age) setAge(profile.age);
        if (profile.gender) setGender(profile.gender);
        if (profile.activityLevel) setActivityLevel(profile.activityLevel);
        setDailyCalorieGoal(profile.dailyCalorieGoal);
        setDailyProteinGoal(profile.dailyProteinGoal);
        setDailyCarbsGoal(profile.dailyCarbsGoal);
        setDailyFatGoal(profile.dailyFatGoal);
        // If profile exists, start at diet step for editing
        setStep('diet');
      } catch {
        // No profile yet, that's okay
      }
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const handleDietSelect = (type: string) => {
    setDietType(type);
    const template = templates.find(t => t.dietType === type);
    if (template) {
      setDailyCalorieGoal(template.baselineCalories);
      setDailyProteinGoal(template.baselineProtein);
      setDailyCarbsGoal(template.baselineCarbs);
      setDailyFatGoal(template.baselineFat);
    }
  };

  const handleCalculateGoals = async () => {
    if (!weight || !height || !age) return;

    try {
      const result = await profileApi.calculateGoals({
        weight: Number(weight),
        height: Number(height),
        age: Number(age),
        gender,
        activityLevel,
        dietType
      });
      setCalculatedGoals(result);
      setDailyCalorieGoal(result.goals.calories);
      setDailyProteinGoal(result.goals.protein);
      setDailyCarbsGoal(result.goals.carbs);
      setDailyFatGoal(result.goals.fat);
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to calculate goals');
    }
  };

  const handleSave = async () => {
    setSaving(true);
    setError(null);

    try {
      const data: ProfileUpdateData = {
        dietType,
        dailyCalorieGoal,
        dailyProteinGoal,
        dailyCarbsGoal,
        dailyFatGoal,
      };

      if (weight) data.weight = Number(weight);
      if (height) data.height = Number(height);
      if (age) data.age = Number(age);
      data.gender = gender;
      data.activityLevel = activityLevel;

      await profileApi.updateProfile(data);
      setStep('complete');
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to save profile');
    } finally {
      setSaving(false);
    }
  };

  const selectedTemplate = templates.find(t => t.dietType === dietType);

  if (loading) {
    return (
      <div className="container">
        <div style={{ textAlign: 'center', padding: 'var(--spacing-xl)', opacity: 0.6 }}>
          Loading...
        </div>
      </div>
    );
  }

  return (
    <div className="container">
      <h1>{existingProfile ? 'Edit Diet Profile' : 'Set Up Your Diet Profile'}</h1>

      {error && (
        <Card style={{ marginBottom: 'var(--spacing-xl)', padding: 'var(--spacing-lg)', backgroundColor: 'var(--color-error)', color: 'white' }}>
          <p style={{ margin: 0 }}>{error}</p>
        </Card>
      )}

      {/* Step indicator */}
      <div style={{ display: 'flex', gap: 'var(--spacing-sm)', marginBottom: 'var(--spacing-xl)' }}>
        {(['diet', 'metrics', 'goals'] as const).map((s, i) => (
          <div
            key={s}
            style={{
              flex: 1,
              height: '4px',
              borderRadius: '2px',
              backgroundColor: step === s || ['diet', 'metrics', 'goals'].indexOf(step) > i
                ? 'var(--color-primary-gradient-start)'
                : 'var(--color-surface-secondary)',
              transition: 'background-color 0.3s'
            }}
          />
        ))}
      </div>

      {step === 'diet' && (
        <>
          <SectionHeader>Choose Your Diet Type</SectionHeader>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
            {templates.map(template => (
              <Card
                key={template.dietType}
                style={{
                  padding: 'var(--spacing-md)',
                  cursor: 'pointer',
                  border: dietType === template.dietType ? '2px solid var(--color-primary-gradient-start)' : '2px solid transparent',
                  transition: 'border-color 0.2s'
                }}
                onClick={() => handleDietSelect(template.dietType)}
              >
                <h3 style={{ margin: '0 0 var(--spacing-xs) 0' }}>{template.name}</h3>
                <p style={{ margin: 0, fontSize: 'var(--font-size-sm)', opacity: 0.7 }}>
                  {template.description}
                </p>
                <div style={{ marginTop: 'var(--spacing-sm)', fontSize: 'var(--font-size-xs)', opacity: 0.5 }}>
                  Protein {Math.round(template.proteinRatio * 100)}% | Carbs {Math.round(template.carbsRatio * 100)}% | Fat {Math.round(template.fatRatio * 100)}%
                </div>
              </Card>
            ))}
          </div>

          <Button variant="primary" fullWidth onClick={() => setStep('metrics')}>
            Continue
          </Button>
        </>
      )}

      {step === 'metrics' && (
        <>
          <SectionHeader>Your Physical Metrics (Optional)</SectionHeader>
          <p style={{ opacity: 0.7, marginBottom: 'var(--spacing-lg)' }}>
            Enter your metrics to get personalized calorie and macro goals, or skip to use defaults.
          </p>

          <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
            <div style={{ display: 'grid', gap: 'var(--spacing-md)' }}>
              <div>
                <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                  Weight (kg)
                </label>
                <input
                  type="number"
                  value={weight}
                  onChange={(e) => setWeight(e.target.value ? Number(e.target.value) : '')}
                  placeholder="70"
                  style={{
                    width: '100%',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--border-radius-sm)',
                    border: '1px solid var(--color-surface-secondary)',
                    backgroundColor: 'var(--color-surface-primary)',
                    color: 'var(--color-text-primary)',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                  Height (cm)
                </label>
                <input
                  type="number"
                  value={height}
                  onChange={(e) => setHeight(e.target.value ? Number(e.target.value) : '')}
                  placeholder="175"
                  style={{
                    width: '100%',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--border-radius-sm)',
                    border: '1px solid var(--color-surface-secondary)',
                    backgroundColor: 'var(--color-surface-primary)',
                    color: 'var(--color-text-primary)',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                  Age
                </label>
                <input
                  type="number"
                  value={age}
                  onChange={(e) => setAge(e.target.value ? Number(e.target.value) : '')}
                  placeholder="30"
                  style={{
                    width: '100%',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--border-radius-sm)',
                    border: '1px solid var(--color-surface-secondary)',
                    backgroundColor: 'var(--color-surface-primary)',
                    color: 'var(--color-text-primary)',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                  Gender
                </label>
                <select
                  value={gender}
                  onChange={(e) => setGender(e.target.value as 'male' | 'female')}
                  style={{
                    width: '100%',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--border-radius-sm)',
                    border: '1px solid var(--color-surface-secondary)',
                    backgroundColor: 'var(--color-surface-primary)',
                    color: 'var(--color-text-primary)',
                  }}
                >
                  <option value="male">Male</option>
                  <option value="female">Female</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                  Activity Level
                </label>
                <select
                  value={activityLevel}
                  onChange={(e) => setActivityLevel(e.target.value as typeof activityLevel)}
                  style={{
                    width: '100%',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--border-radius-sm)',
                    border: '1px solid var(--color-surface-secondary)',
                    backgroundColor: 'var(--color-surface-primary)',
                    color: 'var(--color-text-primary)',
                  }}
                >
                  <option value="sedentary">Sedentary (little or no exercise)</option>
                  <option value="light">Light (exercise 1-3 days/week)</option>
                  <option value="moderate">Moderate (exercise 3-5 days/week)</option>
                  <option value="active">Active (exercise 6-7 days/week)</option>
                  <option value="very_active">Very Active (intense daily exercise)</option>
                </select>
              </div>
            </div>

            {weight && height && age && (
              <Button
                variant="secondary"
                fullWidth
                style={{ marginTop: 'var(--spacing-md)' }}
                onClick={handleCalculateGoals}
              >
                Calculate My Goals
              </Button>
            )}
          </Card>

          <div style={{ display: 'flex', gap: 'var(--spacing-md)' }}>
            <Button variant="secondary" fullWidth onClick={() => setStep('diet')}>
              Back
            </Button>
            <Button variant="primary" fullWidth onClick={() => setStep('goals')}>
              Continue
            </Button>
          </div>
        </>
      )}

      {step === 'goals' && (
        <>
          <SectionHeader>Your Daily Goals</SectionHeader>
          {calculatedGoals && (
            <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-lg)', backgroundColor: 'var(--color-success)', color: 'white' }}>
              <p style={{ margin: 0, fontSize: 'var(--font-size-sm)' }}>
                Goals calculated based on your metrics and {calculatedGoals.template.name} diet.
              </p>
            </Card>
          )}

          {selectedTemplate && (
            <p style={{ opacity: 0.7, marginBottom: 'var(--spacing-lg)' }}>
              Based on {selectedTemplate.name}: {selectedTemplate.description}
            </p>
          )}

          <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
            <div style={{ display: 'grid', gap: 'var(--spacing-md)' }}>
              <div>
                <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                  Daily Calories
                </label>
                <input
                  type="number"
                  value={dailyCalorieGoal}
                  onChange={(e) => setDailyCalorieGoal(Number(e.target.value))}
                  style={{
                    width: '100%',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--border-radius-sm)',
                    border: '1px solid var(--color-surface-secondary)',
                    backgroundColor: 'var(--color-surface-primary)',
                    color: 'var(--color-text-primary)',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                  Daily Protein (g)
                </label>
                <input
                  type="number"
                  value={dailyProteinGoal}
                  onChange={(e) => setDailyProteinGoal(Number(e.target.value))}
                  style={{
                    width: '100%',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--border-radius-sm)',
                    border: '1px solid var(--color-surface-secondary)',
                    backgroundColor: 'var(--color-surface-primary)',
                    color: 'var(--color-text-primary)',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                  Daily Carbs (g)
                </label>
                <input
                  type="number"
                  value={dailyCarbsGoal}
                  onChange={(e) => setDailyCarbsGoal(Number(e.target.value))}
                  style={{
                    width: '100%',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--border-radius-sm)',
                    border: '1px solid var(--color-surface-secondary)',
                    backgroundColor: 'var(--color-surface-primary)',
                    color: 'var(--color-text-primary)',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                  Daily Fat (g)
                </label>
                <input
                  type="number"
                  value={dailyFatGoal}
                  onChange={(e) => setDailyFatGoal(Number(e.target.value))}
                  style={{
                    width: '100%',
                    padding: 'var(--spacing-sm)',
                    borderRadius: 'var(--border-radius-sm)',
                    border: '1px solid var(--color-surface-secondary)',
                    backgroundColor: 'var(--color-surface-primary)',
                    color: 'var(--color-text-primary)',
                  }}
                />
              </div>
            </div>
          </Card>

          <div style={{ display: 'flex', gap: 'var(--spacing-md)' }}>
            <Button variant="secondary" fullWidth onClick={() => setStep('metrics')}>
              Back
            </Button>
            <Button variant="primary" fullWidth onClick={handleSave} disabled={saving}>
              {saving ? 'Saving...' : 'Save Profile'}
            </Button>
          </div>
        </>
      )}

      {step === 'complete' && (
        <Card style={{ padding: 'var(--spacing-xl)', textAlign: 'center' }}>
          <div style={{ fontSize: '48px', marginBottom: 'var(--spacing-md)' }}>✓</div>
          <h2 style={{ marginBottom: 'var(--spacing-md)' }}>Profile Saved!</h2>
          <p style={{ opacity: 0.7, marginBottom: 'var(--spacing-xl)' }}>
            Your {selectedTemplate?.name} diet profile has been set up. Start tracking your meals to see your progress!
          </p>
          <div style={{ display: 'flex', gap: 'var(--spacing-md)', flexDirection: 'column' }}>
            <Button variant="primary" fullWidth onClick={() => navigate('/')}>
              Go to Dashboard
            </Button>
            <Button variant="secondary" fullWidth onClick={() => navigate('/camera')}>
              Log Your First Meal
            </Button>
          </div>
        </Card>
      )}
    </div>
  );
}

import { useState, useEffect } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { Card, SectionHeader, Button, Input } from '../components/ui';
import { mealApi } from '../services/api';
import type { Meal, MealUpdateRequest, ApiError } from '../services/api';

interface EditableFood {
  id: string;
  name: string;
  portion: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  confidence?: number;
  isExpanded: boolean;
}

export default function MealEdit() {
  const location = useLocation();
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const originalMeal = location.state?.meal as Meal | undefined;

  const [mealDate, setMealDate] = useState('');
  const [mealTime, setMealTime] = useState('');
  const [foods, setFoods] = useState<EditableFood[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (originalMeal) {
      // Parse timestamp
      const date = new Date(originalMeal.timestamp);
      setMealDate(date.toISOString().split('T')[0]);
      setMealTime(date.toTimeString().slice(0, 5));

      // Convert foods to editable format
      const mealFoods = originalMeal.foods || [];
      setFoods(
        mealFoods.map((food, idx) => ({
          id: `food-${idx}`,
          name: food.name,
          portion: food.portion,
          calories: food.nutrition.calories,
          protein: food.nutrition.protein,
          carbs: food.nutrition.carbs,
          fat: food.nutrition.fat,
          confidence: food.confidence,
          isExpanded: false,
        }))
      );
    }
  }, [originalMeal]);

  if (!originalMeal || !id) {
    return (
      <div className="container">
        <h1>Edit Meal</h1>
        <p>Meal not found</p>
        <Button variant="secondary" onClick={() => navigate('/history')}>
          ← Back to History
        </Button>
      </div>
    );
  }

  const totalCalories = foods.reduce((sum, f) => sum + f.calories, 0);
  const totalProtein = foods.reduce((sum, f) => sum + f.protein, 0);
  const totalCarbs = foods.reduce((sum, f) => sum + f.carbs, 0);
  const totalFat = foods.reduce((sum, f) => sum + f.fat, 0);

  const handleFoodChange = (foodId: string, field: keyof EditableFood, value: string | number | boolean) => {
    setFoods(prev =>
      prev.map(food =>
        food.id === foodId ? { ...food, [field]: value } : food
      )
    );
  };

  const toggleFoodExpanded = (foodId: string) => {
    setFoods(prev =>
      prev.map(food =>
        food.id === foodId ? { ...food, isExpanded: !food.isExpanded } : food
      )
    );
  };

  const addNewFood = () => {
    const newFood: EditableFood = {
      id: `food-${Date.now()}`,
      name: 'New Item',
      portion: '1 serving',
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      confidence: 0.8,
      isExpanded: true,
    };
    setFoods(prev => [...prev, newFood]);
  };

  const removeFood = (foodId: string) => {
    setFoods(prev => prev.filter(f => f.id !== foodId));
  };

  const handleSave = async () => {
    setSaving(true);
    setError(null);

    try {
      // Build timestamp from date and time
      const timestamp = new Date(`${mealDate}T${mealTime}:00`).toISOString();

      const updateData: MealUpdateRequest = {
        foods: foods.map(f => ({
          name: f.name,
          portion: f.portion,
          nutrition: {
            calories: f.calories,
            protein: f.protein,
            carbs: f.carbs,
            fat: f.fat,
          },
          confidence: f.confidence || 0.8,
        })),
        totals: {
          calories: totalCalories,
          protein: totalProtein,
          carbs: totalCarbs,
          fat: totalFat,
        },
        timestamp,
      };

      const updatedMeal = await mealApi.updateMeal(id, updateData);
      navigate(`/history/${id}`, { state: { meal: updatedMeal }, replace: true });
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to update meal');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="container">
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-md)' }}>
          <Button variant="secondary" onClick={() => navigate(-1)}>
            ← Cancel
          </Button>
          <h1 style={{ margin: 0 }}>Edit Meal</h1>
        </div>
        <Button variant="primary" onClick={handleSave} disabled={saving}>
          {saving ? 'Saving...' : '💾 Save'}
        </Button>
      </div>

      {error && (
        <Card style={{ marginBottom: 'var(--spacing-lg)', padding: 'var(--spacing-md)', backgroundColor: 'var(--color-error)', color: 'white' }}>
          <p style={{ margin: 0 }}>{error}</p>
        </Card>
      )}

      {/* Thumbnail preview */}
      {(originalMeal.thumbnail || originalMeal.imageUrl) && (
        <img
          src={originalMeal.thumbnail || originalMeal.imageUrl}
          alt="Meal"
          style={{
            width: '100%',
            maxHeight: '200px',
            objectFit: 'contain',
            borderRadius: 'var(--border-radius-md)',
            marginBottom: 'var(--spacing-lg)',
          }}
        />
      )}

      {/* Date & Time */}
      <SectionHeader>📅 Date & Time</SectionHeader>
      <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-lg)' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--spacing-md)' }}>
          <div>
            <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)', opacity: 0.7 }}>
              Date
            </label>
            <Input
              type="date"
              value={mealDate}
              onChange={(e) => setMealDate(e.target.value)}
              style={{ width: '100%' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)', opacity: 0.7 }}>
              Time
            </label>
            <Input
              type="time"
              value={mealTime}
              onChange={(e) => setMealTime(e.target.value)}
              style={{ width: '100%' }}
            />
          </div>
        </div>
      </Card>

      {/* Totals (auto-calculated) */}
      <SectionHeader>📊 Totals (Auto-calculated)</SectionHeader>
      <div className="stats-grid" style={{ marginBottom: 'var(--spacing-lg)' }}>
        <Card gradient={1}>
          <h3>Calories</h3>
          <p style={{ fontSize: 'var(--font-size-2xl)', margin: 0 }}>{Math.round(totalCalories)}</p>
        </Card>
        <Card gradient={2}>
          <h3>Protein</h3>
          <p style={{ fontSize: 'var(--font-size-2xl)', margin: 0 }}>{Math.round(totalProtein)}g</p>
        </Card>
        <Card gradient={3}>
          <h3>Carbs</h3>
          <p style={{ fontSize: 'var(--font-size-2xl)', margin: 0 }}>{Math.round(totalCarbs)}g</p>
        </Card>
        <Card gradient={4}>
          <h3>Fat</h3>
          <p style={{ fontSize: 'var(--font-size-2xl)', margin: 0 }}>{Math.round(totalFat)}g</p>
        </Card>
      </div>

      {/* Food Items */}
      <SectionHeader>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
          <span>🍽️ Food Items</span>
          <Button variant="secondary" onClick={addNewFood}>
            + Add Item
          </Button>
        </div>
      </SectionHeader>

      {foods.length === 0 && (
        <Card style={{ padding: 'var(--spacing-lg)', textAlign: 'center', marginBottom: 'var(--spacing-md)' }}>
          <p style={{ opacity: 0.6, margin: 0 }}>No food items. Click "Add Item" to add one.</p>
        </Card>
      )}

      {foods.map((food) => (
        <Card key={food.id} style={{ marginBottom: 'var(--spacing-md)', padding: 'var(--spacing-md)' }}>
          {/* Food header - always visible */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ flex: 1 }}>
              <Input
                type="text"
                value={food.name}
                onChange={(e) => handleFoodChange(food.id, 'name', e.target.value)}
                placeholder="Food name"
                style={{ fontWeight: 600, marginBottom: 'var(--spacing-xs)' }}
              />
              <Input
                type="text"
                value={food.portion}
                onChange={(e) => handleFoodChange(food.id, 'portion', e.target.value)}
                placeholder="Portion size"
                style={{ fontSize: 'var(--font-size-sm)', opacity: 0.8 }}
              />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 'var(--spacing-xs)' }}>
              <span style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                {Math.round(food.calories)} cal
              </span>
              <Button
                variant="secondary"
                onClick={() => toggleFoodExpanded(food.id)}
                style={{ padding: '4px 8px', fontSize: 'var(--font-size-sm)' }}
              >
                {food.isExpanded ? '▲ Less' : '▼ More'}
              </Button>
            </div>
          </div>

          {/* Expanded nutrition editing */}
          {food.isExpanded && (
            <div style={{ marginTop: 'var(--spacing-md)', paddingTop: 'var(--spacing-md)', borderTop: '1px solid var(--color-border)' }}>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 'var(--spacing-md)' }}>
                <div>
                  <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-xs)', opacity: 0.7 }}>
                    Calories
                  </label>
                  <Input
                    type="number"
                    value={food.calories}
                    onChange={(e) => handleFoodChange(food.id, 'calories', parseFloat(e.target.value) || 0)}
                    style={{ width: '100%' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-xs)', opacity: 0.7 }}>
                    Protein (g)
                  </label>
                  <Input
                    type="number"
                    value={food.protein}
                    onChange={(e) => handleFoodChange(food.id, 'protein', parseFloat(e.target.value) || 0)}
                    style={{ width: '100%' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-xs)', opacity: 0.7 }}>
                    Carbs (g)
                  </label>
                  <Input
                    type="number"
                    value={food.carbs}
                    onChange={(e) => handleFoodChange(food.id, 'carbs', parseFloat(e.target.value) || 0)}
                    style={{ width: '100%' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-xs)', opacity: 0.7 }}>
                    Fat (g)
                  </label>
                  <Input
                    type="number"
                    value={food.fat}
                    onChange={(e) => handleFoodChange(food.id, 'fat', parseFloat(e.target.value) || 0)}
                    style={{ width: '100%' }}
                  />
                </div>
              </div>

              <Button
                variant="secondary"
                onClick={() => removeFood(food.id)}
                style={{ marginTop: 'var(--spacing-md)', color: 'var(--color-error)' }}
              >
                🗑️ Remove Item
              </Button>
            </div>
          )}
        </Card>
      ))}
    </div>
  );
}

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, Button } from '../components/ui';
import { useAuth } from '../contexts/AuthContext';
import { mealApi } from '../services/api';
import type { Meal, ApiError } from '../services/api';

export default function History() {
  const navigate = useNavigate();
  const { isGuest } = useAuth();
  const [meals, setMeals] = useState<Meal[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchMeals = async () => {
    if (isGuest) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const data = await mealApi.getMeals();
      setMeals(data);
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to load meal history');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMeals();
  }, [isGuest]);

  const formatDate = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleDateString('en-US', { 
      month: 'short', 
      day: 'numeric', 
      hour: 'numeric', 
      minute: '2-digit' 
    });
  };

  return (
    <div className="container">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--spacing-lg)' }}>
        <h1 style={{ margin: 0 }}>Meal History</h1>
        {!isGuest && (
          <Button variant="secondary" onClick={fetchMeals} disabled={loading}>
            {loading ? '⟳' : '↻'} Refresh
          </Button>
        )}
      </div>

      {isGuest && (
        <Card style={{ marginBottom: 'var(--spacing-xl)', padding: 'var(--spacing-lg)' }}>
          <h3 style={{ marginTop: 0 }}>Guest Mode</h3>
          <p style={{ fontSize: 'var(--font-size-sm)', opacity: 0.8, marginBottom: 0 }}>
            Meal history is not available in guest mode. Sign up or log in to save your meals.
          </p>
        </Card>
      )}

      {error && (
        <Card style={{ marginBottom: 'var(--spacing-xl)', padding: 'var(--spacing-lg)', backgroundColor: 'var(--color-error)', color: 'white' }}>
          <p style={{ margin: 0, marginBottom: 'var(--spacing-md)' }}>{error}</p>
          <Button variant="secondary" onClick={fetchMeals}>
            Retry
          </Button>
        </Card>
      )}

      {loading && !meals.length && (
        <div style={{ textAlign: 'center', padding: 'var(--spacing-xl)', opacity: 0.6 }}>
          Loading meals...
        </div>
      )}

      {!isGuest && !loading && meals.length === 0 && !error && (
        <Card style={{ padding: 'var(--spacing-xl)', textAlign: 'center' }}>
          <p style={{ opacity: 0.6, marginBottom: 'var(--spacing-md)' }}>No meals yet</p>
          <Button variant="primary" onClick={() => navigate('/camera')}>
            📸 Capture Your First Meal
          </Button>
        </Card>
      )}

      {meals.length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-md)' }}>
          {meals.map((meal) => (
            <Card 
              key={meal.id} 
              style={{ 
                padding: 'var(--spacing-md)', 
                cursor: 'pointer',
                transition: 'transform 0.2s',
              }}
              onClick={() => navigate(`/history/${meal.id}`, { state: { meal } })}
            >
              <div style={{ display: 'flex', gap: 'var(--spacing-md)' }}>
                <div 
                  style={{ 
                    width: '80px', 
                    height: '80px', 
                    borderRadius: 'var(--border-radius-md)',
                    backgroundColor: 'var(--color-surface-secondary)',
                    flexShrink: 0,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    overflow: 'hidden'
                  }}
                >
                  {meal.imageUrl ? (
                    <img 
                      src={meal.imageUrl} 
                      alt="Meal" 
                      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    />
                  ) : (
                    <span style={{ fontSize: '2rem' }}>🍽️</span>
                  )}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6, marginBottom: 'var(--spacing-xs)' }}>
                    {formatDate(meal.timestamp)}
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--spacing-sm)', fontSize: 'var(--font-size-sm)' }}>
                    <div>
                      <div style={{ opacity: 0.6, fontSize: 'var(--font-size-xs)' }}>Cal</div>
                      <div style={{ fontWeight: 600 }}>{Math.round(meal.totals.calories)}</div>
                    </div>
                    <div>
                      <div style={{ opacity: 0.6, fontSize: 'var(--font-size-xs)' }}>Protein</div>
                      <div style={{ fontWeight: 600 }}>{Math.round(meal.totals.protein)}g</div>
                    </div>
                    <div>
                      <div style={{ opacity: 0.6, fontSize: 'var(--font-size-xs)' }}>Carbs</div>
                      <div style={{ fontWeight: 600 }}>{Math.round(meal.totals.carbs)}g</div>
                    </div>
                    <div>
                      <div style={{ opacity: 0.6, fontSize: 'var(--font-size-xs)' }}>Fat</div>
                      <div style={{ fontWeight: 600 }}>{Math.round(meal.totals.fat)}g</div>
                    </div>
                  </div>
                  {meal.items.length > 0 && (
                    <div style={{ marginTop: 'var(--spacing-xs)', fontSize: 'var(--font-size-xs)', opacity: 0.6 }}>
                      {meal.items.map(item => item.name).join(', ')}
                    </div>
                  )}
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

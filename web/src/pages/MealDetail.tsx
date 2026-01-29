import { useState, type MouseEvent } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { Card, SectionHeader, Button } from '../components/ui';
import { mealApi } from '../services/api';
import type { Meal, ApiError } from '../services/api';

export default function MealDetail() {
  const location = useLocation();
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const meal = location.state?.meal as Meal | undefined;
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!meal) {
    return (
      <div className="container">
        <h1>Meal Detail</h1>
        <p>Meal not found</p>
        <Button variant="secondary" onClick={() => navigate('/history')}>
          ← Back to History
        </Button>
      </div>
    );
  }

  const formatDate = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleDateString('en-US', { 
      weekday: 'long',
      month: 'long', 
      day: 'numeric', 
      year: 'numeric',
      hour: 'numeric', 
      minute: '2-digit' 
    });
  };

  const handleDelete = async () => {
    if (!id) return;
    
    setDeleting(true);
    setError(null);

    try {
      await mealApi.deleteMeal(id);
      navigate('/history', { replace: true });
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to delete meal');
      setShowDeleteConfirm(false);
    } finally {
      setDeleting(false);
    }
  };

  const handleEdit = () => {
    navigate(`/history/${id}/edit`, { state: { meal } });
  };

  return (
    <div className="container">
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-md)' }}>
          <Button variant="secondary" onClick={() => navigate('/history')}>
            ← Back
          </Button>
          <h1 style={{ margin: 0 }}>Meal Detail</h1>
        </div>
        <div style={{ display: 'flex', gap: 'var(--spacing-sm)' }}>
          <Button variant="secondary" onClick={handleEdit}>
            ✏️ Edit
          </Button>
          <Button 
            variant="secondary" 
            onClick={() => setShowDeleteConfirm(true)}
            style={{ color: 'var(--color-error)' }}
          >
            🗑️ Delete
          </Button>
        </div>
      </div>

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div 
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowDeleteConfirm(false)}
        >
          <Card 
            style={{ 
              padding: 'var(--spacing-xl)', 
              maxWidth: '400px', 
              margin: 'var(--spacing-md)' 
            }}
            onClick={(e: MouseEvent<HTMLDivElement>) => e.stopPropagation()}
          >
            <h3 style={{ marginTop: 0 }}>Delete Meal?</h3>
            <p style={{ opacity: 0.8, marginBottom: 'var(--spacing-lg)' }}>
              Are you sure you want to delete this meal? This action cannot be undone.
            </p>
            <div style={{ display: 'flex', gap: 'var(--spacing-md)', justifyContent: 'flex-end' }}>
              <Button variant="secondary" onClick={() => setShowDeleteConfirm(false)} disabled={deleting}>
                Cancel
              </Button>
              <Button 
                variant="primary" 
                onClick={handleDelete}
                disabled={deleting}
                style={{ backgroundColor: 'var(--color-error)' }}
              >
                {deleting ? 'Deleting...' : 'Delete'}
              </Button>
            </div>
          </Card>
        </div>
      )}

      {error && (
        <Card style={{ marginBottom: 'var(--spacing-lg)', padding: 'var(--spacing-md)', backgroundColor: 'var(--color-error)', color: 'white' }}>
          <p style={{ margin: 0 }}>{error}</p>
        </Card>
      )}

      {(meal.thumbnail || meal.imageUrl) && (
        <img 
          src={meal.thumbnail || meal.imageUrl} 
          alt="Meal" 
          style={{ 
            width: '100%', 
            maxHeight: '40vh', 
            objectFit: 'contain',
            borderRadius: 'var(--border-radius-md)',
            marginBottom: 'var(--spacing-md)'
          }} 
        />
      )}

      <p style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6, marginBottom: 'var(--spacing-xl)' }}>
        {formatDate(meal.timestamp)}
      </p>

      <SectionHeader>Totals</SectionHeader>
      <div className="stats-grid" style={{ marginBottom: 'var(--spacing-xl)' }}>
        <Card gradient={1}>
          <h3>Calories</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{Math.round(meal.totals.calories)}</p>
        </Card>
        <Card gradient={2}>
          <h3>Protein</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{Math.round(meal.totals.protein)}g</p>
        </Card>
        <Card gradient={3}>
          <h3>Carbs</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{Math.round(meal.totals.carbs)}g</p>
        </Card>
        <Card gradient={4}>
          <h3>Fat</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{Math.round(meal.totals.fat)}g</p>
        </Card>
      </div>

      <SectionHeader>Items</SectionHeader>
      {(() => {
        // Handle both 'foods' (from backend) and 'items' (legacy)
        const foods = meal.foods || [];
        const items = meal.items || [];
        
        if (foods.length > 0) {
          return foods.map((food, idx) => (
            <Card key={idx} style={{ marginBottom: 'var(--spacing-md)', padding: 'var(--spacing-md)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--spacing-sm)' }}>
                <h3 style={{ marginTop: 0, marginBottom: 0 }}>{food.name}</h3>
                {food.portion && (
                  <span style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>{food.portion}</span>
                )}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--spacing-sm)', fontSize: 'var(--font-size-sm)' }}>
                <div>
                  <div style={{ opacity: 0.6 }}>Cal</div>
                  <div style={{ fontWeight: 600 }}>{Math.round(food.nutrition.calories)}</div>
                </div>
                <div>
                  <div style={{ opacity: 0.6 }}>Protein</div>
                  <div style={{ fontWeight: 600 }}>{Math.round(food.nutrition.protein)}g</div>
                </div>
                <div>
                  <div style={{ opacity: 0.6 }}>Carbs</div>
                  <div style={{ fontWeight: 600 }}>{Math.round(food.nutrition.carbs)}g</div>
                </div>
                <div>
                  <div style={{ opacity: 0.6 }}>Fat</div>
                  <div style={{ fontWeight: 600 }}>{Math.round(food.nutrition.fat)}g</div>
                </div>
              </div>
              {food.confidence && (
                <div style={{ marginTop: 'var(--spacing-sm)', fontSize: 'var(--font-size-xs)', opacity: 0.6 }}>
                  Confidence: {Math.round(food.confidence * 100)}%
                </div>
              )}
            </Card>
          ));
        } else if (items.length > 0) {
          return items.map((item, idx) => (
            <Card key={idx} style={{ marginBottom: 'var(--spacing-md)', padding: 'var(--spacing-md)' }}>
              <h3 style={{ marginTop: 0, marginBottom: 'var(--spacing-sm)' }}>{item.name}</h3>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--spacing-sm)', fontSize: 'var(--font-size-sm)' }}>
                <div>
                  <div style={{ opacity: 0.6 }}>Cal</div>
                  <div style={{ fontWeight: 600 }}>{Math.round(item.calories)}</div>
                </div>
                <div>
                  <div style={{ opacity: 0.6 }}>Protein</div>
                  <div style={{ fontWeight: 600 }}>{Math.round(item.protein)}g</div>
                </div>
                <div>
                  <div style={{ opacity: 0.6 }}>Carbs</div>
                  <div style={{ fontWeight: 600 }}>{Math.round(item.carbs)}g</div>
                </div>
                <div>
                  <div style={{ opacity: 0.6 }}>Fat</div>
                  <div style={{ fontWeight: 600 }}>{Math.round(item.fat)}g</div>
                </div>
              </div>
            </Card>
          ));
        } else {
          return (
            <Card style={{ padding: 'var(--spacing-lg)', textAlign: 'center' }}>
              <p style={{ opacity: 0.6, margin: 0 }}>No items detected</p>
            </Card>
          );
        }
      })()}
    </div>
  );
}

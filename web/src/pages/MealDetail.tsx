import { useLocation, useNavigate } from 'react-router-dom';
import { Card, SectionHeader, Button } from '../components/ui';
import type { Meal } from '../services/api';

export default function MealDetail() {
  const location = useLocation();
  const navigate = useNavigate();
  const meal = location.state?.meal as Meal | undefined;

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

  return (
    <div className="container">
      <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-lg)' }}>
        <Button variant="secondary" onClick={() => navigate('/history')}>
          ← Back
        </Button>
        <h1 style={{ margin: 0, flex: 1 }}>Meal Detail</h1>
      </div>

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
      <div style={{ display: 'grid', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
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

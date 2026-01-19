import { useNavigate } from 'react-router-dom';
import { Card, Button, SectionHeader } from '../components/ui';
import { useAuth } from '../contexts/AuthContext';

export default function Home() {
  const navigate = useNavigate();
  const { isGuest } = useAuth();

  return (
    <div className="container">
      <h1>NutritionAI</h1>
      
      {isGuest && (
        <Card style={{ marginBottom: 'var(--spacing-xl)', padding: 'var(--spacing-lg)' }}>
          <h3 style={{ marginTop: 0 }}>Guest Mode</h3>
          <p style={{ fontSize: 'var(--font-size-sm)', opacity: 0.8, marginBottom: 0 }}>
            You are in guest mode. Your data is stored locally only and won't sync across devices.
          </p>
        </Card>
      )}
      
      <SectionHeader>Today</SectionHeader>
      <div style={{ display: 'grid', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <Card gradient={1}>
          <h3>Calories</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0</p>
        </Card>
        <Card gradient={2}>
          <h3>Protein</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0g</p>
        </Card>
        <Card gradient={3}>
          <h3>Carbs</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0g</p>
        </Card>
        <Card gradient={4}>
          <h3>Fat</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0g</p>
        </Card>
      </div>

      <SectionHeader>Week</SectionHeader>
      <div style={{ display: 'grid', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <Card gradient={1}>
          <h3>Calories</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0</p>
        </Card>
        <Card gradient={2}>
          <h3>Protein</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0g</p>
        </Card>
        <Card gradient={3}>
          <h3>Carbs</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0g</p>
        </Card>
        <Card gradient={4}>
          <h3>Fat</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0g</p>
        </Card>
      </div>

      <SectionHeader>All Time</SectionHeader>
      <div style={{ display: 'grid', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <Card gradient={1}>
          <h3>Total Meals</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0</p>
        </Card>
        <Card gradient={2}>
          <h3>Avg Calories</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0</p>
        </Card>
      </div>

      <SectionHeader>Quick Capture</SectionHeader>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-md)' }}>
        <Button variant="primary" fullWidth onClick={() => navigate('/camera')}>
          📸 Capture Meal
        </Button>
        <Button variant="secondary" fullWidth onClick={() => navigate('/camera')}>
          🍽️ Quick Snap
        </Button>
      </div>
    </div>
  );
}

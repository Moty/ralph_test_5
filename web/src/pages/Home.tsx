import { useNavigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { Card, Button, SectionHeader } from '../components/ui';
import { useAuth } from '../contexts/AuthContext';
import { userApi } from '../services/api';
import type { UserStats, ApiError } from '../services/api';

export default function Home() {
  const navigate = useNavigate();
  const { isGuest } = useAuth();
  const [stats, setStats] = useState<UserStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchStats = async () => {
    if (isGuest) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const data = await userApi.getStats();
      setStats(data);
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to load stats');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, [isGuest]);

  return (
    <div className="container">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--spacing-lg)' }}>
        <h1 style={{ margin: 0 }}>NutritionAI</h1>
        {!isGuest && (
          <Button variant="secondary" onClick={fetchStats} disabled={loading}>
            {loading ? '⟳' : '↻'} Refresh
          </Button>
        )}
      </div>
      
      {isGuest && (
        <Card style={{ marginBottom: 'var(--spacing-xl)', padding: 'var(--spacing-lg)' }}>
          <h3 style={{ marginTop: 0 }}>Guest Mode</h3>
          <p style={{ fontSize: 'var(--font-size-sm)', opacity: 0.8, marginBottom: 0 }}>
            You are in guest mode. Your data is stored locally only and won't sync across devices.
          </p>
        </Card>
      )}

      {error && (
        <Card style={{ marginBottom: 'var(--spacing-xl)', padding: 'var(--spacing-lg)', backgroundColor: 'var(--color-error)', color: 'white' }}>
          <p style={{ margin: 0, marginBottom: 'var(--spacing-md)' }}>{error}</p>
          <Button variant="secondary" onClick={fetchStats}>
            Retry
          </Button>
        </Card>
      )}

      {loading && !stats && (
        <div style={{ textAlign: 'center', padding: 'var(--spacing-xl)', opacity: 0.6 }}>
          Loading stats...
        </div>
      )}
      
      <SectionHeader>Today</SectionHeader>
      <div style={{ display: 'grid', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <Card gradient={1}>
          <h3>Calories</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{stats?.today.totalCalories ?? 0}</p>
        </Card>
        <Card gradient={2}>
          <h3>Protein</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{stats?.today.totalProtein ?? 0}g</p>
        </Card>
        <Card gradient={3}>
          <h3>Carbs</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{stats?.today.totalCarbs ?? 0}g</p>
        </Card>
        <Card gradient={4}>
          <h3>Fat</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{stats?.today.totalFat ?? 0}g</p>
        </Card>
      </div>

      <SectionHeader>Week</SectionHeader>
      <div style={{ display: 'grid', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <Card gradient={1}>
          <h3>Calories</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{stats?.week.totalCalories ?? 0}</p>
        </Card>
        <Card gradient={2}>
          <h3>Protein</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{stats?.week.totalProtein ?? 0}g</p>
        </Card>
        <Card gradient={3}>
          <h3>Carbs</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{stats?.week.totalCarbs ?? 0}g</p>
        </Card>
        <Card gradient={4}>
          <h3>Fat</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{stats?.week.totalFat ?? 0}g</p>
        </Card>
      </div>

      <SectionHeader>All Time</SectionHeader>
      <div style={{ display: 'grid', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <Card gradient={1}>
          <h3>Total Meals</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{stats?.allTime.count ?? 0}</p>
        </Card>
        <Card gradient={2}>
          <h3>Avg Calories</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{Math.round(stats?.allTime.avgCalories ?? 0)}</p>
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

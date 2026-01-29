import { useNavigate, Link } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { Card, Button, SectionHeader } from '../components/ui';
import { useAuth } from '../contexts/AuthContext';
import { userApi } from '../services/api';
import type { UserStats, ApiError } from '../services/api';

function ProgressBar({ value, max, color }: { value: number; max: number; color: string }) {
  const percentage = Math.min((value / max) * 100, 100);
  const isOver = value > max;

  return (
    <div style={{ width: '100%', backgroundColor: 'var(--color-surface-secondary)', borderRadius: '4px', height: '6px', overflow: 'hidden' }}>
      <div
        style={{
          width: `${percentage}%`,
          height: '100%',
          backgroundColor: isOver ? 'var(--color-error)' : color,
          transition: 'width 0.3s ease'
        }}
      />
    </div>
  );
}

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
      <div className="page-header">
        <h1>NutritionAI</h1>
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

      {/* Profile setup prompt */}
      {!isGuest && stats && !stats.hasProfile && (
        <Card style={{ marginBottom: 'var(--spacing-xl)', padding: 'var(--spacing-lg)', backgroundColor: 'var(--color-primary-gradient-start)', color: 'white' }}>
          <h3 style={{ marginTop: 0, marginBottom: 'var(--spacing-sm)' }}>Set Up Your Diet Profile</h3>
          <p style={{ fontSize: 'var(--font-size-sm)', opacity: 0.9, marginBottom: 'var(--spacing-md)' }}>
            Get personalized nutrition goals and track your diet compliance.
          </p>
          <Button variant="secondary" onClick={() => navigate('/profile')}>
            Set Up Profile
          </Button>
        </Card>
      )}

      {/* Diet compliance summary */}
      {stats?.dietInfo && (
        <>
          <SectionHeader>{stats.dietInfo.dietName} Progress</SectionHeader>
          <Card style={{
            padding: 'var(--spacing-md)',
            marginBottom: 'var(--spacing-xl)',
            backgroundColor: stats.dietInfo.todayCompliance.isOnTrack ? 'rgba(76, 175, 80, 0.1)' : 'rgba(255, 152, 0, 0.1)'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--spacing-md)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-sm)' }}>
                <span style={{ fontSize: '24px' }}>{stats.dietInfo.todayCompliance.isOnTrack ? '✓' : '⚠'}</span>
                <span style={{ fontWeight: 'var(--font-weight-medium)' }}>
                  {stats.dietInfo.todayCompliance.isOnTrack ? 'On Track!' : 'Needs Attention'}
                </span>
              </div>
              <span style={{ fontSize: 'var(--font-size-lg)', fontWeight: 'var(--font-weight-bold)' }}>
                {Math.round(stats.dietInfo.todayCompliance.overallCompliance * 100)}%
              </span>
            </div>

            {/* Macro progress bars */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-sm)' }}>
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '2px', fontSize: 'var(--font-size-sm)' }}>
                  <span>Calories</span>
                  <span>{stats.today.totalCalories} / {stats.dietInfo.goals.dailyCalories}</span>
                </div>
                <ProgressBar value={stats.today.totalCalories} max={stats.dietInfo.goals.dailyCalories} color="var(--color-primary-gradient-start)" />
              </div>
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '2px', fontSize: 'var(--font-size-sm)' }}>
                  <span>Protein</span>
                  <span>{stats.today.totalProtein}g / {stats.dietInfo.goals.dailyProtein}g</span>
                </div>
                <ProgressBar value={stats.today.totalProtein} max={stats.dietInfo.goals.dailyProtein} color="#4CAF50" />
              </div>
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '2px', fontSize: 'var(--font-size-sm)' }}>
                  <span>Carbs</span>
                  <span>{stats.today.totalCarbs}g / {stats.dietInfo.goals.dailyCarbs}g</span>
                </div>
                <ProgressBar value={stats.today.totalCarbs} max={stats.dietInfo.goals.dailyCarbs} color="#FF9800" />
              </div>
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '2px', fontSize: 'var(--font-size-sm)' }}>
                  <span>Fat</span>
                  <span>{stats.today.totalFat}g / {stats.dietInfo.goals.dailyFat}g</span>
                </div>
                <ProgressBar value={stats.today.totalFat} max={stats.dietInfo.goals.dailyFat} color="#9C27B0" />
              </div>
            </div>

            {/* Suggestions */}
            {stats.dietInfo.todayCompliance.suggestions.length > 0 && (
              <div style={{ marginTop: 'var(--spacing-md)', padding: 'var(--spacing-sm)', backgroundColor: 'var(--color-surface-secondary)', borderRadius: 'var(--border-radius-sm)' }}>
                <div style={{ fontSize: 'var(--font-size-sm)', fontWeight: 'var(--font-weight-medium)', marginBottom: 'var(--spacing-xs)' }}>Suggestions:</div>
                {stats.dietInfo.todayCompliance.suggestions.slice(0, 2).map((suggestion, i) => (
                  <div key={i} style={{ fontSize: 'var(--font-size-sm)', opacity: 0.8 }}>• {suggestion}</div>
                ))}
              </div>
            )}

            <Link to="/progress" style={{ display: 'block', textAlign: 'center', marginTop: 'var(--spacing-md)', color: 'var(--color-primary-gradient-start)', fontSize: 'var(--font-size-sm)' }}>
              View Detailed Progress →
            </Link>
          </Card>
        </>
      )}

      <SectionHeader>Today</SectionHeader>
      <div className="stats-grid" style={{ marginBottom: 'var(--spacing-xl)' }}>
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
      <div className="stats-grid" style={{ marginBottom: 'var(--spacing-xl)' }}>
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
      <div className="two-col-grid" style={{ marginBottom: 'var(--spacing-xl)' }}>
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
      <div className="quick-actions">
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

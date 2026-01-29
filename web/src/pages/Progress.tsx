import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, SectionHeader, Button } from '../components/ui';
import { progressApi } from '../services/api';
import type {
  TodayProgressResponse,
  WeekProgressResponse,
  MonthlyProgressResponse,
  DailyProgress,
  ApiError
} from '../services/api';

type Tab = 'today' | 'week' | 'month';

// Calculate compliance score from individual compliance values
function getComplianceScore(progress: DailyProgress): number {
  const carbs = progress.carbsCompliance ?? 1;
  const protein = progress.proteinCompliance ?? 1;
  const fat = progress.fatCompliance ?? 1;
  return (carbs + protein + fat) / 3;
}

function ProgressBar({ value, max, color }: { value: number; max: number; color: string }) {
  const percentage = Math.min((value / max) * 100, 100);
  const isOver = value > max;

  return (
    <div style={{ width: '100%', backgroundColor: 'var(--color-surface-secondary)', borderRadius: '4px', height: '8px', overflow: 'hidden' }}>
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

function MacroCard({ label, current, goal, unit, color }: { label: string; current: number; goal: number; unit: string; color: string }) {
  const percentage = goal > 0 ? Math.round((current / goal) * 100) : 0;
  const remaining = goal - current;

  return (
    <Card style={{ padding: 'var(--spacing-md)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--spacing-sm)' }}>
        <span style={{ fontWeight: 'var(--font-weight-medium)' }}>{label}</span>
        <span style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>{percentage}%</span>
      </div>
      <ProgressBar value={current} max={goal} color={color} />
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
        <span>{current}{unit} / {goal}{unit}</span>
        <span style={{ opacity: 0.6 }}>{remaining > 0 ? `${remaining}${unit} left` : 'Goal reached!'}</span>
      </div>
    </Card>
  );
}

export default function Progress() {
  const navigate = useNavigate();
  const [tab, setTab] = useState<Tab>('today');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [needsSetup, setNeedsSetup] = useState(false);

  const [todayData, setTodayData] = useState<TodayProgressResponse | null>(null);
  const [weekData, setWeekData] = useState<WeekProgressResponse | null>(null);
  const [monthData, setMonthData] = useState<MonthlyProgressResponse | null>(null);

  useEffect(() => {
    loadData(tab);
  }, [tab]);

  const loadData = async (currentTab: Tab) => {
    setLoading(true);
    setError(null);

    try {
      if (currentTab === 'today') {
        const data = await progressApi.getToday();
        setTodayData(data);
      } else if (currentTab === 'week') {
        const data = await progressApi.getWeek();
        setWeekData(data);
      } else if (currentTab === 'month') {
        const data = await progressApi.getMonthly();
        setMonthData(data);
      }
    } catch (err) {
      const apiError = err as ApiError & { needsSetup?: boolean };
      if (apiError.status === 404) {
        setNeedsSetup(true);
      } else {
        setError(apiError.message || 'Failed to load progress');
      }
    } finally {
      setLoading(false);
    }
  };

  if (needsSetup) {
    return (
      <div className="container">
        <h1>Progress</h1>
        <Card style={{ padding: 'var(--spacing-xl)', textAlign: 'center' }}>
          <h2 style={{ marginBottom: 'var(--spacing-md)' }}>Set Up Your Profile</h2>
          <p style={{ opacity: 0.7, marginBottom: 'var(--spacing-xl)' }}>
            To track your diet progress, you need to set up your diet profile first.
          </p>
          <Button variant="primary" onClick={() => navigate('/profile')}>
            Set Up Profile
          </Button>
        </Card>
      </div>
    );
  }

  return (
    <div className="container">
      <h1>Progress</h1>

      {/* Tab selector */}
      <div style={{ display: 'flex', gap: 'var(--spacing-sm)', marginBottom: 'var(--spacing-xl)' }}>
        {(['today', 'week', 'month'] as const).map((t) => (
          <Button
            key={t}
            variant={tab === t ? 'primary' : 'secondary'}
            onClick={() => setTab(t)}
            style={{ flex: 1, textTransform: 'capitalize' }}
          >
            {t}
          </Button>
        ))}
      </div>

      {error && (
        <Card style={{ marginBottom: 'var(--spacing-xl)', padding: 'var(--spacing-lg)', backgroundColor: 'var(--color-error)', color: 'white' }}>
          <p style={{ margin: 0 }}>{error}</p>
        </Card>
      )}

      {loading && (
        <div style={{ textAlign: 'center', padding: 'var(--spacing-xl)', opacity: 0.6 }}>
          Loading progress...
        </div>
      )}

      {/* Today's Progress */}
      {tab === 'today' && todayData && !loading && (
        <>
          <SectionHeader>Today's Macros</SectionHeader>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
            <MacroCard
              label="Calories"
              current={todayData.progress.totalCalories}
              goal={todayData.progress.goalCalories}
              unit=""
              color="var(--color-primary-gradient-start)"
            />
            <MacroCard
              label="Protein"
              current={todayData.progress.totalProtein}
              goal={todayData.progress.goalProtein}
              unit="g"
              color="#4CAF50"
            />
            <MacroCard
              label="Carbs"
              current={todayData.progress.totalCarbs}
              goal={todayData.progress.goalCarbs}
              unit="g"
              color="#FF9800"
            />
            <MacroCard
              label="Fat"
              current={todayData.progress.totalFat}
              goal={todayData.progress.goalFat}
              unit="g"
              color="#9C27B0"
            />
          </div>

          {/* Compliance Status */}
          <SectionHeader>Status</SectionHeader>
          <Card style={{
            padding: 'var(--spacing-md)',
            marginBottom: 'var(--spacing-xl)',
            backgroundColor: todayData.progress.isOnTrack ? 'rgba(76, 175, 80, 0.1)' : 'rgba(255, 152, 0, 0.1)'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-sm)', marginBottom: 'var(--spacing-sm)' }}>
              <span style={{ fontSize: '24px' }}>{todayData.progress.isOnTrack ? '✓' : '⚠'}</span>
              <span style={{ fontWeight: 'var(--font-weight-medium)' }}>
                {todayData.progress.isOnTrack ? 'On Track!' : 'Needs Attention'}
              </span>
            </div>
            <p style={{ margin: 0, fontSize: 'var(--font-size-sm)', opacity: 0.7 }}>
              Compliance Score: {Math.round(getComplianceScore(todayData.progress) * 100)}%
            </p>
            {todayData.progress.netCarbs !== undefined && (
              <p style={{ margin: 'var(--spacing-sm) 0 0 0', fontSize: 'var(--font-size-sm)', opacity: 0.7 }}>
                Net Carbs: {todayData.progress.netCarbs}g
              </p>
            )}
          </Card>

          {/* Meal Suggestions */}
          {todayData.suggestions.length > 0 && (
            <>
              <SectionHeader>Next Meal Suggestions</SectionHeader>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
                {todayData.suggestions.map((suggestion, i) => (
                  <Card key={i} style={{ padding: 'var(--spacing-md)', display: 'flex', alignItems: 'flex-start', gap: 'var(--spacing-sm)' }}>
                    <span style={{ fontSize: '20px' }}>💡</span>
                    <p style={{ margin: 0, fontSize: 'var(--font-size-sm)' }}>{suggestion}</p>
                  </Card>
                ))}
              </div>
            </>
          )}

          {/* Remaining Budget */}
          <SectionHeader>Remaining Today</SectionHeader>
          <Card style={{ padding: 'var(--spacing-md)' }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 'var(--spacing-md)' }}>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Calories</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)', color: todayData.remaining.calories < 0 ? 'var(--color-error)' : 'inherit' }}>
                  {todayData.remaining.calories}
                </div>
              </div>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Protein</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)', color: todayData.remaining.protein < 0 ? 'var(--color-error)' : 'inherit' }}>
                  {todayData.remaining.protein}g
                </div>
              </div>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Carbs</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)', color: todayData.remaining.carbs < 0 ? 'var(--color-error)' : 'inherit' }}>
                  {todayData.remaining.carbs}g
                </div>
              </div>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Fat</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)', color: todayData.remaining.fat < 0 ? 'var(--color-error)' : 'inherit' }}>
                  {todayData.remaining.fat}g
                </div>
              </div>
            </div>
          </Card>
        </>
      )}

      {/* Week's Progress */}
      {tab === 'week' && weekData && !loading && (
        <>
          <SectionHeader>This Week ({new Date(weekData.weekStart).toLocaleDateString()} - {new Date(weekData.weekEnd).toLocaleDateString()})</SectionHeader>

          {/* Weekly Summary */}
          <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 'var(--spacing-md)' }}>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Avg Calories</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)' }}>
                  {Math.round(weekData.summary.avgCalories)}
                </div>
              </div>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Total Meals</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)' }}>
                  {weekData.summary.totalMeals}
                </div>
              </div>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Days Tracked</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)' }}>
                  {weekData.summary.daysTracked}
                </div>
              </div>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Compliance Rate</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)' }}>
                  {Math.round(weekData.summary.complianceRate * 100)}%
                </div>
              </div>
            </div>
          </Card>

          {/* Daily breakdown */}
          <SectionHeader>Daily Breakdown</SectionHeader>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-sm)' }}>
            {weekData.days.map((day) => (
              <Card key={day.id} style={{ padding: 'var(--spacing-md)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: 'var(--font-weight-medium)' }}>
                      {new Date(day.date).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
                    </div>
                    <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>
                      {day.mealCount} meals | {day.totalCalories} cal
                    </div>
                  </div>
                  <div style={{
                    width: '40px',
                    height: '40px',
                    borderRadius: '50%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    backgroundColor: day.isOnTrack ? 'rgba(76, 175, 80, 0.2)' : 'rgba(255, 152, 0, 0.2)',
                    color: day.isOnTrack ? '#4CAF50' : '#FF9800',
                    fontWeight: 'var(--font-weight-bold)',
                    fontSize: 'var(--font-size-sm)'
                  }}>
                    {Math.round(getComplianceScore(day) * 100)}%
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </>
      )}

      {/* Monthly Progress */}
      {tab === 'month' && monthData && !loading && (
        <>
          <SectionHeader>Last 12 Weeks</SectionHeader>

          {/* Monthly Summary */}
          <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--spacing-md)' }}>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Avg Compliance</div>
                <div style={{ fontSize: 'var(--font-size-2xl)', fontWeight: 'var(--font-weight-bold)' }}>
                  {Math.round(monthData.summary.avgComplianceRate * 100)}%
                </div>
              </div>
              <div style={{
                padding: 'var(--spacing-xs) var(--spacing-sm)',
                borderRadius: 'var(--border-radius-sm)',
                backgroundColor: monthData.summary.trend === 'improving' ? 'rgba(76, 175, 80, 0.2)' :
                  monthData.summary.trend === 'declining' ? 'rgba(244, 67, 54, 0.2)' : 'rgba(158, 158, 158, 0.2)',
                color: monthData.summary.trend === 'improving' ? '#4CAF50' :
                  monthData.summary.trend === 'declining' ? '#F44336' : '#9E9E9E',
                fontSize: 'var(--font-size-sm)',
                fontWeight: 'var(--font-weight-medium)'
              }}>
                {monthData.summary.trend === 'improving' ? '↑ Improving' :
                  monthData.summary.trend === 'declining' ? '↓ Declining' : '→ Stable'}
              </div>
            </div>
            <p style={{ margin: 0, fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>
              {monthData.summary.totalWeeks} weeks tracked
            </p>
          </Card>

          {/* Weekly summaries */}
          <SectionHeader>Weekly Summaries</SectionHeader>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-sm)' }}>
            {monthData.weeks.map((week) => (
              <Card key={week.id} style={{ padding: 'var(--spacing-md)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: 'var(--font-weight-medium)' }}>
                      Week of {new Date(week.weekStart).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                    </div>
                    <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>
                      {week.totalMeals} meals | Avg {Math.round(week.avgCalories)} cal/day
                    </div>
                  </div>
                  <div style={{
                    width: '50px',
                    height: '50px',
                    borderRadius: '50%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    backgroundColor: week.complianceRate >= 0.8 ? 'rgba(76, 175, 80, 0.2)' :
                      week.complianceRate >= 0.6 ? 'rgba(255, 193, 7, 0.2)' : 'rgba(244, 67, 54, 0.2)',
                    color: week.complianceRate >= 0.8 ? '#4CAF50' :
                      week.complianceRate >= 0.6 ? '#FFC107' : '#F44336',
                    fontWeight: 'var(--font-weight-bold)',
                    fontSize: 'var(--font-size-sm)'
                  }}>
                    {Math.round(week.complianceRate * 100)}%
                  </div>
                </div>
              </Card>
            ))}
            {monthData.weeks.length === 0 && (
              <Card style={{ padding: 'var(--spacing-xl)', textAlign: 'center' }}>
                <p style={{ margin: 0, opacity: 0.6 }}>No weekly data yet. Keep tracking your meals!</p>
              </Card>
            )}
          </div>
        </>
      )}
    </div>
  );
}

import { useState, useEffect } from 'react';
import { Card, SectionHeader, Button } from '../components/ui';
import { ketoneApi, profileApi } from '../services/api';
import type {
  KetoneLog,
  KetoneStats,
  KetosisStatus,
  ApiError
} from '../services/api';

function getKetosisColor(level: string): string {
  switch (level) {
    case 'optimal': return '#4CAF50';
    case 'moderate': return '#8BC34A';
    case 'light': return '#FFC107';
    case 'high': return '#FF9800';
    default: return '#9E9E9E';
  }
}

function KetosisIndicator({ status }: { status: KetosisStatus }) {
  const color = getKetosisColor(status.level);

  return (
    <Card style={{
      padding: 'var(--spacing-lg)',
      textAlign: 'center',
      backgroundColor: `${color}15`,
      borderLeft: `4px solid ${color}`
    }}>
      <div style={{ fontSize: '48px', marginBottom: 'var(--spacing-sm)' }}>
        {status.isInKetosis ? '🔥' : '⚡'}
      </div>
      <h3 style={{ margin: '0 0 var(--spacing-xs) 0', color }}>{status.level.toUpperCase()}</h3>
      <p style={{ margin: 0, opacity: 0.7 }}>{status.message}</p>
    </Card>
  );
}

export default function Ketones() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isKetoUser, setIsKetoUser] = useState<boolean | null>(null);

  // Latest reading
  const [latestLog, setLatestLog] = useState<KetoneLog | null>(null);
  const [latestStatus, setLatestStatus] = useState<KetosisStatus | null>(null);

  // Recent logs
  const [logs, setLogs] = useState<KetoneLog[]>([]);
  const [stats, setStats] = useState<KetoneStats | null>(null);

  // New entry form
  const [showForm, setShowForm] = useState(false);
  const [ketoneLevel, setKetoneLevel] = useState<string>('');
  const [measurementType, setMeasurementType] = useState<string>('blood');
  const [notes, setNotes] = useState<string>('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    checkUserAndLoadData();
  }, []);

  const checkUserAndLoadData = async () => {
    setLoading(true);
    setError(null);

    try {
      // Check if user has a keto profile
      const { profile } = await profileApi.getProfile();
      const isKeto = profile.dietType === 'keto';
      setIsKetoUser(isKeto);

      if (isKeto) {
        await loadKetoneData();
      }
    } catch (err) {
      const apiError = err as ApiError;
      if (apiError.status === 404) {
        setIsKetoUser(false);
      } else {
        setError(apiError.message || 'Failed to load data');
      }
    } finally {
      setLoading(false);
    }
  };

  const loadKetoneData = async () => {
    try {
      const [latestResponse, recentResponse] = await Promise.all([
        ketoneApi.getLatest(),
        ketoneApi.getRecent(30)
      ]);

      setLatestLog(latestResponse.log);
      setLatestStatus(latestResponse.ketosisStatus);
      setLogs(recentResponse.logs);
      setStats(recentResponse.stats);
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to load ketone data');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!ketoneLevel) return;

    setSaving(true);
    setError(null);

    try {
      const response = await ketoneApi.log(
        parseFloat(ketoneLevel),
        measurementType,
        notes || undefined
      );

      // Update state with new data
      setLatestLog(response.log);
      setLatestStatus(response.ketosisStatus);
      setLogs([response.log, ...logs]);

      // Reset form
      setKetoneLevel('');
      setNotes('');
      setShowForm(false);

      // Reload stats
      const recentResponse = await ketoneApi.getRecent(30);
      setStats(recentResponse.stats);
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to save ketone reading');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this ketone reading?')) return;

    try {
      await ketoneApi.delete(id);
      setLogs(logs.filter(l => l.id !== id));

      // Reload latest and stats
      await loadKetoneData();
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to delete reading');
    }
  };

  if (loading) {
    return (
      <div className="container">
        <div style={{ textAlign: 'center', padding: 'var(--spacing-xl)', opacity: 0.6 }}>
          Loading...
        </div>
      </div>
    );
  }

  if (isKetoUser === false) {
    return (
      <div className="container">
        <h1>Ketone Tracking</h1>
        <Card style={{ padding: 'var(--spacing-xl)', textAlign: 'center' }}>
          <div style={{ fontSize: '48px', marginBottom: 'var(--spacing-md)' }}>🥑</div>
          <h2 style={{ marginBottom: 'var(--spacing-md)' }}>Keto Diet Required</h2>
          <p style={{ opacity: 0.7, marginBottom: 'var(--spacing-xl)' }}>
            Ketone tracking is available for users on the Keto diet. Switch your diet type to Keto to access this feature.
          </p>
          <Button variant="primary" onClick={() => window.location.href = '/profile'}>
            Update Diet Profile
          </Button>
        </Card>
      </div>
    );
  }

  return (
    <div className="container">
      <div className="page-header">
        <h1>Ketone Tracking</h1>
        <Button variant="primary" onClick={() => setShowForm(!showForm)}>
          {showForm ? 'Cancel' : '+ Log Reading'}
        </Button>
      </div>

      {error && (
        <Card style={{ marginBottom: 'var(--spacing-xl)', padding: 'var(--spacing-lg)', backgroundColor: 'var(--color-error)', color: 'white' }}>
          <p style={{ margin: 0 }}>{error}</p>
        </Card>
      )}

      {/* New Entry Form */}
      {showForm && (
        <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
          <form onSubmit={handleSubmit}>
            <h3 style={{ margin: '0 0 var(--spacing-md) 0' }}>Log Ketone Reading</h3>

            <div style={{ marginBottom: 'var(--spacing-md)' }}>
              <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                Ketone Level (mmol/L) *
              </label>
              <input
                type="number"
                step="0.1"
                min="0"
                max="10"
                value={ketoneLevel}
                onChange={(e) => setKetoneLevel(e.target.value)}
                placeholder="e.g., 1.5"
                required
                style={{
                  width: '100%',
                  padding: 'var(--spacing-sm)',
                  borderRadius: 'var(--border-radius-sm)',
                  border: '1px solid var(--color-surface-secondary)',
                  backgroundColor: 'var(--color-surface-primary)',
                  color: 'var(--color-text-primary)',
                  fontSize: 'var(--font-size-lg)'
                }}
              />
            </div>

            <div style={{ marginBottom: 'var(--spacing-md)' }}>
              <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                Measurement Type
              </label>
              <select
                value={measurementType}
                onChange={(e) => setMeasurementType(e.target.value)}
                style={{
                  width: '100%',
                  padding: 'var(--spacing-sm)',
                  borderRadius: 'var(--border-radius-sm)',
                  border: '1px solid var(--color-surface-secondary)',
                  backgroundColor: 'var(--color-surface-primary)',
                  color: 'var(--color-text-primary)',
                }}
              >
                <option value="blood">Blood (most accurate)</option>
                <option value="breath">Breath</option>
                <option value="urine">Urine strips</option>
              </select>
            </div>

            <div style={{ marginBottom: 'var(--spacing-md)' }}>
              <label style={{ display: 'block', marginBottom: 'var(--spacing-xs)', fontSize: 'var(--font-size-sm)' }}>
                Notes (optional)
              </label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="e.g., fasting, after workout, etc."
                rows={2}
                style={{
                  width: '100%',
                  padding: 'var(--spacing-sm)',
                  borderRadius: 'var(--border-radius-sm)',
                  border: '1px solid var(--color-surface-secondary)',
                  backgroundColor: 'var(--color-surface-primary)',
                  color: 'var(--color-text-primary)',
                  resize: 'vertical'
                }}
              />
            </div>

            <Button variant="primary" fullWidth disabled={saving || !ketoneLevel}>
              {saving ? 'Saving...' : 'Save Reading'}
            </Button>
          </form>
        </Card>
      )}

      {/* Current Status */}
      {latestStatus && (
        <>
          <SectionHeader>Current Status</SectionHeader>
          <div style={{ marginBottom: 'var(--spacing-xl)' }}>
            <KetosisIndicator status={latestStatus} />
            {latestLog && (
              <p style={{ textAlign: 'center', marginTop: 'var(--spacing-sm)', opacity: 0.6, fontSize: 'var(--font-size-sm)' }}>
                Last reading: {latestLog.ketoneLevel} mmol/L ({new Date(latestLog.timestamp).toLocaleString()})
              </p>
            )}
          </div>
        </>
      )}

      {/* Stats */}
      {stats && stats.totalDays > 0 && (
        <>
          <SectionHeader>30-Day Statistics</SectionHeader>
          <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 'var(--spacing-md)' }}>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Average</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)' }}>
                  {stats.avgLevel} mmol/L
                </div>
              </div>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Days in Ketosis</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)' }}>
                  {stats.daysInKetosis}/{stats.totalDays}
                </div>
              </div>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Range</div>
                <div style={{ fontSize: 'var(--font-size-xl)', fontWeight: 'var(--font-weight-bold)' }}>
                  {stats.minLevel} - {stats.maxLevel}
                </div>
              </div>
              <div>
                <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>Trend</div>
                <div style={{
                  fontSize: 'var(--font-size-xl)',
                  fontWeight: 'var(--font-weight-bold)',
                  color: stats.trend === 'improving' ? '#4CAF50' :
                    stats.trend === 'declining' ? '#F44336' : 'inherit'
                }}>
                  {stats.trend === 'improving' ? '↑' : stats.trend === 'declining' ? '↓' : '→'} {stats.trend}
                </div>
              </div>
            </div>

            <div style={{ marginTop: 'var(--spacing-md)' }}>
              <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6, marginBottom: 'var(--spacing-xs)' }}>
                Ketosis Rate
              </div>
              <div style={{ width: '100%', backgroundColor: 'var(--color-surface-secondary)', borderRadius: '4px', height: '8px', overflow: 'hidden' }}>
                <div
                  style={{
                    width: `${stats.ketosisRate * 100}%`,
                    height: '100%',
                    backgroundColor: stats.ketosisRate >= 0.7 ? '#4CAF50' : stats.ketosisRate >= 0.5 ? '#FFC107' : '#FF9800',
                    transition: 'width 0.3s ease'
                  }}
                />
              </div>
              <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6, marginTop: 'var(--spacing-xs)' }}>
                {Math.round(stats.ketosisRate * 100)}% of days in ketosis
              </div>
            </div>
          </Card>
        </>
      )}

      {/* Ketosis Levels Guide */}
      <SectionHeader>Ketosis Levels Guide</SectionHeader>
      <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-sm)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-sm)' }}>
            <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: '#9E9E9E' }} />
            <span><strong>0 - 0.5:</strong> Not in ketosis</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-sm)' }}>
            <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: '#FFC107' }} />
            <span><strong>0.5 - 1.0:</strong> Light ketosis</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-sm)' }}>
            <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: '#8BC34A' }} />
            <span><strong>1.0 - 1.5:</strong> Moderate ketosis</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-sm)' }}>
            <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: '#4CAF50' }} />
            <span><strong>1.5 - 3.0:</strong> Optimal ketosis</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--spacing-sm)' }}>
            <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: '#FF9800' }} />
            <span><strong>3.0+:</strong> High (monitor closely)</span>
          </div>
        </div>
      </Card>

      {/* Recent Logs */}
      <SectionHeader>Recent Readings</SectionHeader>
      {logs.length === 0 ? (
        <Card style={{ padding: 'var(--spacing-xl)', textAlign: 'center' }}>
          <p style={{ margin: 0, opacity: 0.6 }}>No ketone readings yet. Log your first reading!</p>
        </Card>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-sm)' }}>
          {logs.map((log) => (
            <Card key={log.id} style={{ padding: 'var(--spacing-md)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <div style={{ fontSize: 'var(--font-size-lg)', fontWeight: 'var(--font-weight-bold)' }}>
                    {log.ketoneLevel} mmol/L
                  </div>
                  <div style={{ fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>
                    {new Date(log.timestamp).toLocaleString()} • {log.measurementType}
                  </div>
                  {log.notes && (
                    <div style={{ fontSize: 'var(--font-size-sm)', marginTop: 'var(--spacing-xs)', opacity: 0.7 }}>
                      {log.notes}
                    </div>
                  )}
                </div>
                <button
                  onClick={() => handleDelete(log.id)}
                  style={{
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    opacity: 0.5,
                    fontSize: 'var(--font-size-lg)'
                  }}
                >
                  ×
                </button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

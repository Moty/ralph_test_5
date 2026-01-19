import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, SectionHeader, Button } from '../components/ui';
import { useAuth } from '../contexts/AuthContext';

type Theme = 'system' | 'light' | 'dark';

const AVAILABLE_MODELS = [
  'gemini-2.0-flash',        // Unlimited RPD - RECOMMENDED
  'gemini-2.0-flash-lite',   // Unlimited RPD - Fast & light
  'gemini-2.5-flash-lite',   // Unlimited RPD - Good balance
  'gemini-3-flash',          // 10K RPD - Newest
  'gemini-2.5-flash',        // 10K RPD
  'gemini-2.5-pro',          // 10K RPD - Best quality
  'gemini-3-pro'             // 250 RPD - Highest quality
];

export default function Settings() {
  const navigate = useNavigate();
  const { logout, isAuthenticated } = useAuth();
  const [theme, setTheme] = useState<Theme>('system');
  const [selectedModel, setSelectedModel] = useState<string>(AVAILABLE_MODELS[0]);
  const [showApiOverride, setShowApiOverride] = useState(false);
  const [apiBaseUrl, setApiBaseUrl] = useState('');

  useEffect(() => {
    const savedTheme = localStorage.getItem('theme') as Theme | null;
    if (savedTheme) {
      setTheme(savedTheme);
      applyTheme(savedTheme);
    }

    const savedModel = localStorage.getItem('selectedModel');
    if (savedModel) {
      setSelectedModel(savedModel);
    }

    const showOverride = import.meta.env.VITE_SHOW_API_OVERRIDE === 'true';
    setShowApiOverride(showOverride);

    const savedUrl = localStorage.getItem('apiBaseUrl');
    if (savedUrl) {
      setApiBaseUrl(savedUrl);
    }
  }, []);

  const applyTheme = (newTheme: Theme) => {
    const root = document.documentElement;
    
    if (newTheme === 'system') {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      root.classList.toggle('dark-theme', prefersDark);
    } else {
      root.classList.toggle('dark-theme', newTheme === 'dark');
    }
  };

  const handleThemeChange = (newTheme: Theme) => {
    setTheme(newTheme);
    localStorage.setItem('theme', newTheme);
    applyTheme(newTheme);
  };

  const handleModelChange = (model: string) => {
    setSelectedModel(model);
    localStorage.setItem('selectedModel', model);
  };

  const handleApiUrlChange = (url: string) => {
    setApiBaseUrl(url);
    if (url) {
      localStorage.setItem('apiBaseUrl', url);
    } else {
      localStorage.removeItem('apiBaseUrl');
    }
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="container">
      <h1>Settings</h1>
      
      <SectionHeader>Appearance</SectionHeader>
      <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <h3 style={{ marginTop: 0, marginBottom: 'var(--spacing-md)' }}>Theme</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-sm)' }}>
          {(['system', 'light', 'dark'] as const).map((option) => (
            <label 
              key={option}
              style={{ 
                display: 'flex', 
                alignItems: 'center', 
                padding: 'var(--spacing-sm)',
                cursor: 'pointer',
                borderRadius: 'var(--border-radius-sm)',
                backgroundColor: theme === option ? 'var(--color-surface-secondary)' : 'transparent',
              }}
            >
              <input
                type="radio"
                name="theme"
                value={option}
                checked={theme === option}
                onChange={(e) => handleThemeChange(e.target.value as Theme)}
                style={{ marginRight: 'var(--spacing-sm)' }}
              />
              <span style={{ textTransform: 'capitalize' }}>{option}</span>
            </label>
          ))}
        </div>
      </Card>

      <SectionHeader>AI Model</SectionHeader>
      <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <h3 style={{ marginTop: 0, marginBottom: 'var(--spacing-md)' }}>Model Selection</h3>
        <select 
          value={selectedModel}
          onChange={(e) => handleModelChange(e.target.value)}
          style={{
            width: '100%',
            padding: 'var(--spacing-sm)',
            borderRadius: 'var(--border-radius-sm)',
            border: '1px solid var(--color-surface-secondary)',
            backgroundColor: 'var(--color-surface-primary)',
            color: 'var(--color-text-primary)',
            fontSize: 'var(--font-size-base)',
            cursor: 'pointer'
          }}
        >
          {AVAILABLE_MODELS.map((model) => (
            <option key={model} value={model}>
              {model}
            </option>
          ))}
        </select>
        <div style={{ marginTop: 'var(--spacing-md)', fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>
          <p style={{ marginBottom: 'var(--spacing-xs)' }}>Selected model will be used for meal analysis.</p>
          <p style={{ marginBottom: 0 }}>Recommended: gemini-2.0-flash (Unlimited requests)</p>
        </div>
      </Card>

      {showApiOverride && (
        <>
          <SectionHeader>Developer</SectionHeader>
          <Card style={{ padding: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
            <h3 style={{ marginTop: 0, marginBottom: 'var(--spacing-md)' }}>Backend URL Override</h3>
            <input
              type="text"
              value={apiBaseUrl}
              onChange={(e) => handleApiUrlChange(e.target.value)}
              placeholder="http://localhost:3001"
              style={{
                width: '100%',
                padding: 'var(--spacing-sm)',
                borderRadius: 'var(--border-radius-sm)',
                border: '1px solid var(--color-surface-secondary)',
                backgroundColor: 'var(--color-surface-primary)',
                color: 'var(--color-text-primary)',
                fontSize: 'var(--font-size-base)',
              }}
            />
            <div style={{ marginTop: 'var(--spacing-sm)', fontSize: 'var(--font-size-sm)', opacity: 0.6 }}>
              Leave empty to use default from environment
            </div>
          </Card>
        </>
      )}

      {isAuthenticated && (
        <>
          <SectionHeader>Account</SectionHeader>
          <Card style={{ padding: 'var(--spacing-md)' }}>
            <Button variant="secondary" fullWidth onClick={handleLogout}>
              Sign Out
            </Button>
          </Card>
        </>
      )}
    </div>
  );
}

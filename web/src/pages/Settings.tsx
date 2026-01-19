import { useState, useEffect } from 'react';
import { Card, SectionHeader } from '../components/ui';

type Theme = 'system' | 'light' | 'dark';

export default function Settings() {
  const [theme, setTheme] = useState<Theme>('system');

  useEffect(() => {
    const savedTheme = localStorage.getItem('theme') as Theme | null;
    if (savedTheme) {
      setTheme(savedTheme);
      applyTheme(savedTheme);
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

  return (
    <div className="container">
      <h1>Settings</h1>
      
      <SectionHeader>Appearance</SectionHeader>
      <Card style={{ padding: 'var(--spacing-md)' }}>
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
    </div>
  );
}

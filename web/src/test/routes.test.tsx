import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import Home from '../pages/Home';
import History from '../pages/History';
import Settings from '../pages/Settings';
import { AuthProvider } from '../contexts/AuthContext';

// Mock API module
vi.mock('../services/api', () => ({
  userApi: {
    getStats: vi.fn().mockResolvedValue({
      today: { calories: 0, protein: 0, carbs: 0, fat: 0 },
      week: { calories: 0, protein: 0, carbs: 0, fat: 0 },
      allTime: { calories: 0, protein: 0, carbs: 0, fat: 0 }
    })
  },
  mealApi: {
    getMeals: vi.fn().mockResolvedValue([]),
    analyze: vi.fn()
  },
  setApiUnauthorizedHandler: vi.fn()
}));

const renderWithRouter = (component: React.ReactElement) => {
  return render(
    <BrowserRouter>
      <AuthProvider>
        {component}
      </AuthProvider>
    </BrowserRouter>
  );
};

describe('Route Smoke Tests', () => {
  it('should render Home page', () => {
    renderWithRouter(<Home />);
    expect(screen.getByText('NutritionAI')).toBeInTheDocument();
  });

  it('should render History page', () => {
    renderWithRouter(<History />);
    expect(screen.getByText('Meal History')).toBeInTheDocument();
  });

  it('should render Settings page', () => {
    renderWithRouter(<Settings />);
    expect(screen.getByText('Settings')).toBeInTheDocument();
  });

  it('Home page should display stat sections', () => {
    renderWithRouter(<Home />);
    expect(screen.getByText('Today')).toBeInTheDocument();
    expect(screen.getByText('Week')).toBeInTheDocument();
    expect(screen.getByText('All Time')).toBeInTheDocument();
  });

  it('Settings page should display theme options', () => {
    renderWithRouter(<Settings />);
    expect(screen.getByText('Appearance')).toBeInTheDocument();
    expect(screen.getByText('Theme')).toBeInTheDocument();
  });
});

import { BrowserRouter, Routes, Route, Link, useNavigate, Navigate } from 'react-router-dom';
import { useEffect } from 'react';
import './App.css';
import Home from './pages/Home';
import Camera from './pages/Camera';
import History from './pages/History';
import Settings from './pages/Settings';
import Login from './pages/Login';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { setApiUnauthorizedHandler } from './services/api';

function AppContent() {
  const navigate = useNavigate();
  const { logout, isAuthenticated, isGuest, isLoading } = useAuth();

  useEffect(() => {
    // Handle 401 responses by clearing session and routing to Login
    setApiUnauthorizedHandler(() => {
      logout();
      navigate('/login');
    });
  }, [logout, navigate]);

  // Show nothing while loading auth state
  if (isLoading) {
    return null;
  }

  // If not authenticated and not in guest mode, redirect to login
  const requiresAuth = !isAuthenticated && !isGuest;

  return (
    <div className="app">
      {(isAuthenticated || isGuest) && (
        <nav>
          <Link to="/">Home</Link>
          <Link to="/camera">Camera</Link>
          <Link to="/history">History</Link>
          <Link to="/settings">Settings</Link>
        </nav>
      )}
      <main>
        <Routes>
          <Route path="/login" element={
            isAuthenticated || isGuest ? <Navigate to="/" replace /> : <Login />
          } />
          <Route path="/" element={
            requiresAuth ? <Navigate to="/login" replace /> : <Home />
          } />
          <Route path="/camera" element={
            requiresAuth ? <Navigate to="/login" replace /> : <Camera />
          } />
          <Route path="/history" element={
            requiresAuth ? <Navigate to="/login" replace /> : <History />
          } />
          <Route path="/settings" element={
            requiresAuth ? <Navigate to="/login" replace /> : <Settings />
          } />
        </Routes>
      </main>
    </div>
  );
}

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AppContent />
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;

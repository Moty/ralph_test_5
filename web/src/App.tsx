import { BrowserRouter, Routes, Route, useNavigate, Navigate } from 'react-router-dom';
import { useEffect } from 'react';
import './App.css';
import Home from './pages/Home';
import Camera from './pages/Camera';
import Analyze from './pages/Analyze';
import History from './pages/History';
import MealDetail from './pages/MealDetail';
import MealEdit from './pages/MealEdit';
import Settings from './pages/Settings';
import Login from './pages/Login';
import Profile from './pages/Profile';
import Progress from './pages/Progress';
import Ketones from './pages/Ketones';
import Navbar from './components/Navbar';
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
      <Navbar isAuthenticated={isAuthenticated} isGuest={isGuest} />
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
          <Route path="/camera/analyze" element={
            requiresAuth ? <Navigate to="/login" replace /> : <Analyze />
          } />
          <Route path="/history" element={
            requiresAuth ? <Navigate to="/login" replace /> : <History />
          } />
          <Route path="/history/:id" element={
            requiresAuth ? <Navigate to="/login" replace /> : <MealDetail />
          } />
          <Route path="/history/:id/edit" element={
            requiresAuth ? <Navigate to="/login" replace /> : <MealEdit />
          } />
          <Route path="/settings" element={
            requiresAuth ? <Navigate to="/login" replace /> : <Settings />
          } />
          <Route path="/profile" element={
            requiresAuth ? <Navigate to="/login" replace /> : <Profile />
          } />
          <Route path="/progress" element={
            requiresAuth ? <Navigate to="/login" replace /> : <Progress />
          } />
          <Route path="/ketones" element={
            requiresAuth ? <Navigate to="/login" replace /> : <Ketones />
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

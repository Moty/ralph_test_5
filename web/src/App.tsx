import { BrowserRouter, Routes, Route, Link, useNavigate } from 'react-router-dom';
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
  const { logout } = useAuth();

  useEffect(() => {
    // Handle 401 responses by clearing session and routing to Login
    setApiUnauthorizedHandler(() => {
      logout();
      navigate('/login');
    });
  }, [logout, navigate]);

  return (
    <div className="app">
      <nav>
        <Link to="/">Home</Link>
        <Link to="/camera">Camera</Link>
        <Link to="/history">History</Link>
        <Link to="/settings">Settings</Link>
        <Link to="/login">Login</Link>
      </nav>
      <main>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/camera" element={<Camera />} />
          <Route path="/history" element={<History />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/login" element={<Login />} />
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

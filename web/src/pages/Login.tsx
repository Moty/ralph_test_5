import { useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Button } from '../components/ui';
import './Login.css';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [showRegister, setShowRegister] = useState(false);
  const { login, enterGuestMode } = useAuth();
  const navigate = useNavigate();

  const validateEmail = (email: string): string => {
    if (!email) return 'Email is required';
    if (!/\S+@\S+\.\S+/.test(email)) return 'Invalid email format';
    return '';
  };

  const validatePassword = (password: string): string => {
    if (!password) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    return '';
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setErrorMessage('');

    const emailError = validateEmail(email);
    if (emailError) {
      setErrorMessage(emailError);
      return;
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      setErrorMessage(passwordError);
      return;
    }

    setIsLoading(true);
    try {
      await login(email, password);
      navigate('/');
    } catch (error: any) {
      setErrorMessage(error.message || 'Login failed. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleGuestMode = () => {
    enterGuestMode();
    navigate('/');
  };

  if (showRegister) {
    return <Register onBack={() => setShowRegister(false)} />;
  }

  return (
    <div className="login-page">
      <div className="login-gradient"></div>
      <div className="login-circles">
        <div className="login-circle-1"></div>
        <div className="login-circle-2"></div>
      </div>
      
      <div className="login-content">
        <div className="login-spacer"></div>
        
        <div className="login-header">
          <div className="login-icon">
            <svg width="60" height="60" viewBox="0 0 60 60" fill="none">
              <circle cx="30" cy="30" r="28" fill="white" fillOpacity="0.15"/>
              <path d="M30 10 L35 20 L30 30 L25 20 Z M20 25 L30 30 L20 40 L15 30 Z M40 25 L45 30 L40 40 L30 30 Z M25 40 L30 50 L35 40 L30 35 Z" fill="white"/>
            </svg>
          </div>
          <h1 className="login-title">NutritionAI</h1>
          <p className="login-subtitle">Track your nutrition with AI</p>
        </div>

        <div className="login-spacer"></div>

        <div className="login-card">
          <form onSubmit={handleSubmit}>
            <div className="login-form">
              <div className="login-input-group">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" stroke="currentColor" strokeWidth="2"/>
                  <path d="m22 6-10 7L2 6" stroke="currentColor" strokeWidth="2"/>
                </svg>
                <input
                  type="email"
                  placeholder="Email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={isLoading}
                  autoComplete="email"
                />
              </div>

              <div className="login-input-group">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <rect x="5" y="11" width="14" height="10" rx="2" stroke="currentColor" strokeWidth="2"/>
                  <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" strokeWidth="2"/>
                </svg>
                <input
                  type="password"
                  placeholder="Password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={isLoading}
                  autoComplete="current-password"
                />
              </div>

              {errorMessage && (
                <div className="login-error">
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                    <path d="M8 0a8 8 0 1 0 0 16A8 8 0 0 0 8 0zM7 4h2v5H7V4zm0 6h2v2H7v-2z"/>
                  </svg>
                  <span>{errorMessage}</span>
                </div>
              )}

              <Button type="submit" variant="primary" disabled={isLoading}>
                {isLoading ? (
                  <span className="login-loading">Signing In...</span>
                ) : (
                  <>
                    Sign In
                    <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M10 3l7 7-7 7M3 10h14"/>
                    </svg>
                  </>
                )}
              </Button>

              <button
                type="button"
                className="login-register-link"
                onClick={() => setShowRegister(true)}
              >
                <span className="login-secondary-text">Don't have an account?</span>
                <span className="login-primary-text">Register</span>
              </button>

              <div className="login-divider"></div>

              <button
                type="button"
                className="login-guest-button"
                onClick={handleGuestMode}
              >
                <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                  <circle cx="10" cy="7" r="3"/>
                  <path d="M10 11c-3.3 0-6 2.2-6 5v1h12v-1c0-2.8-2.7-5-6-5z"/>
                  <text x="13" y="8" fontSize="10" fill="currentColor">?</text>
                </svg>
                Try as Guest
              </button>

              <p className="login-guest-disclaimer">
                Guest data is stored locally only and won't sync to the cloud
              </p>
            </div>
          </form>
        </div>

        <div className="login-spacer"></div>
      </div>
    </div>
  );
}

function Register({ onBack }: { onBack: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const { register } = useAuth();
  const navigate = useNavigate();

  const validateEmail = (email: string): string => {
    if (!email) return 'Email is required';
    if (!/\S+@\S+\.\S+/.test(email)) return 'Invalid email format';
    return '';
  };

  const validatePassword = (password: string): string => {
    if (!password) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    return '';
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setErrorMessage('');

    const emailError = validateEmail(email);
    if (emailError) {
      setErrorMessage(emailError);
      return;
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      setErrorMessage(passwordError);
      return;
    }

    if (password !== confirmPassword) {
      setErrorMessage('Passwords do not match');
      return;
    }

    setIsLoading(true);
    try {
      await register(email, password);
      navigate('/');
    } catch (error: any) {
      setErrorMessage(error.message || 'Registration failed. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-page register-page">
      <div className="login-gradient register-gradient"></div>
      
      <div className="login-content">
        <button className="register-close" onClick={onBack}>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" fill="white" fillOpacity="0.8"/>
            <path d="M8 8l8 8M16 8l-8 8" stroke="currentColor" strokeWidth="2"/>
          </svg>
        </button>

        <div className="login-header register-header">
          <div className="login-icon register-icon">
            <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
              <circle cx="20" cy="13" r="7" stroke="white" strokeWidth="2"/>
              <path d="M6 35c0-7.7 6.3-14 14-14s14 6.3 14 14" stroke="white" strokeWidth="2"/>
              <circle cx="28" cy="12" r="8" fill="white" fillOpacity="0.3"/>
              <path d="M28 8v8M24 12h8" stroke="white" strokeWidth="2"/>
            </svg>
          </div>
          <h1 className="login-title">Create Account</h1>
          <p className="login-subtitle">Join NutritionAI to track your meals</p>
        </div>

        <div className="login-card register-card">
          <form onSubmit={handleSubmit}>
            <div className="login-form">
              <div className="login-input-group">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" stroke="currentColor" strokeWidth="2"/>
                  <path d="m22 6-10 7L2 6" stroke="currentColor" strokeWidth="2"/>
                </svg>
                <input
                  type="email"
                  placeholder="Email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={isLoading}
                  autoComplete="email"
                />
              </div>

              <div className="login-input-group">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <rect x="5" y="11" width="14" height="10" rx="2" stroke="currentColor" strokeWidth="2"/>
                  <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" strokeWidth="2"/>
                </svg>
                <input
                  type="password"
                  placeholder="Password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={isLoading}
                  autoComplete="new-password"
                />
              </div>

              <div className="login-input-group">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <rect x="5" y="11" width="14" height="10" rx="2" stroke="currentColor" strokeWidth="2"/>
                  <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" strokeWidth="2"/>
                  <circle cx="12" cy="16" r="1" fill="currentColor"/>
                </svg>
                <input
                  type="password"
                  placeholder="Confirm Password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  disabled={isLoading}
                  autoComplete="new-password"
                />
              </div>

              {errorMessage && (
                <div className="login-error">
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                    <path d="M8 0a8 8 0 1 0 0 16A8 8 0 0 0 8 0zM7 4h2v5H7V4zm0 6h2v2H7v-2z"/>
                  </svg>
                  <span>{errorMessage}</span>
                </div>
              )}

              <Button type="submit" variant="primary" disabled={isLoading}>
                {isLoading ? (
                  <span className="login-loading">Creating Account...</span>
                ) : (
                  <>
                    Create Account
                    <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M10 3l7 7-7 7M3 10h14"/>
                    </svg>
                  </>
                )}
              </Button>

              <button
                type="button"
                className="login-register-link"
                onClick={onBack}
              >
                <span className="login-secondary-text">Already have an account?</span>
                <span className="login-primary-text">Login</span>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}

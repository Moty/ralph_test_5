import { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import './Navbar.css';

interface NavbarProps {
  isAuthenticated: boolean;
  isGuest: boolean;
}

export default function Navbar({ isAuthenticated, isGuest }: NavbarProps) {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isScrolled, setIsScrolled] = useState(false);
  const location = useLocation();

  // Close menu when route changes
  useEffect(() => {
    setIsMenuOpen(false);
  }, [location.pathname]);

  // Add scroll listener for navbar shadow
  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 10);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const isActive = (path: string) => location.pathname === path;

  if (!isAuthenticated && !isGuest) {
    return null;
  }

  return (
    <nav className={`navbar ${isScrolled ? 'navbar-scrolled' : ''}`}>
      <div className="navbar-container">
        {/* Logo */}
        <Link to="/" className="navbar-logo">
          <div className="logo-icon">
            <svg viewBox="0 0 24 24" fill="currentColor" width="28" height="28">
              <path d="M17,8C8,10,5.9,16.17,3.82,21.34L5.71,22L6.66,19.7C7.14,19.87,7.64,20,8,20C19,20,22,3,22,3C21,5,14,5.25,9,6.25C4,7.25,2,11.5,2,13.5C2,15.5,3.75,17.25,3.75,17.25C7,8,17,8,17,8Z"/>
            </svg>
          </div>
          <span className="logo-text">NutritionAI</span>
        </Link>

        {/* Hamburger button for mobile */}
        <button 
          className={`hamburger ${isMenuOpen ? 'hamburger-active' : ''}`}
          onClick={() => setIsMenuOpen(!isMenuOpen)}
          aria-label="Toggle menu"
          aria-expanded={isMenuOpen}
        >
          <span className="hamburger-line"></span>
          <span className="hamburger-line"></span>
          <span className="hamburger-line"></span>
        </button>

        {/* Navigation links */}
        <div className={`navbar-menu ${isMenuOpen ? 'navbar-menu-open' : ''}`}>
          <Link 
            to="/" 
            className={`navbar-link ${isActive('/') ? 'navbar-link-active' : ''}`}
          >
            <span className="navbar-link-icon">🏠</span>
            <span className="navbar-link-text">Home</span>
          </Link>
          <Link 
            to="/progress" 
            className={`navbar-link ${isActive('/progress') ? 'navbar-link-active' : ''}`}
          >
            <span className="navbar-link-icon">📊</span>
            <span className="navbar-link-text">Progress</span>
          </Link>
          <Link 
            to="/camera" 
            className={`navbar-link ${isActive('/camera') ? 'navbar-link-active' : ''}`}
          >
            <span className="navbar-link-icon">📷</span>
            <span className="navbar-link-text">Camera</span>
          </Link>
          <Link 
            to="/history" 
            className={`navbar-link ${isActive('/history') ? 'navbar-link-active' : ''}`}
          >
            <span className="navbar-link-icon">📜</span>
            <span className="navbar-link-text">History</span>
          </Link>
          <Link 
            to="/settings" 
            className={`navbar-link ${isActive('/settings') ? 'navbar-link-active' : ''}`}
          >
            <span className="navbar-link-icon">⚙️</span>
            <span className="navbar-link-text">Settings</span>
          </Link>
        </div>

        {/* Backdrop for mobile menu */}
        {isMenuOpen && (
          <div 
            className="navbar-backdrop" 
            onClick={() => setIsMenuOpen(false)}
          />
        )}
      </div>
    </nav>
  );
}

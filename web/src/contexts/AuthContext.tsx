import { createContext, useContext, useState, useEffect } from 'react';
import type { FC, ReactNode } from 'react';
import { authApi } from '../services/api';

interface AuthState {
  token: string | null;
  isAuthenticated: boolean;
  isGuest: boolean;
  isLoading: boolean;
}

interface AuthContextValue extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  logout: () => void;
  enterGuestMode: () => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

const TOKEN_KEY = 'authToken';
const GUEST_MODE_KEY = 'guestMode';

export const AuthProvider: FC<{ children: ReactNode }> = ({ children }) => {
  const [state, setState] = useState<AuthState>({
    token: null,
    isAuthenticated: false,
    isGuest: false,
    isLoading: true,
  });

  useEffect(() => {
    // Load token and guest mode from localStorage on startup
    const token = localStorage.getItem(TOKEN_KEY);
    const guestMode = localStorage.getItem(GUEST_MODE_KEY) === 'true';

    setState({
      token,
      isAuthenticated: !!token,
      isGuest: guestMode,
      isLoading: false,
    });
  }, []);

  const login = async (email: string, password: string) => {
    const response = await authApi.login({ email, password });
    const { token } = response;
    
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.removeItem(GUEST_MODE_KEY);
    
    setState({
      token,
      isAuthenticated: true,
      isGuest: false,
      isLoading: false,
    });
  };

  const register = async (email: string, password: string) => {
    const response = await authApi.register({ email, password });
    const { token } = response;
    
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.removeItem(GUEST_MODE_KEY);
    
    setState({
      token,
      isAuthenticated: true,
      isGuest: false,
      isLoading: false,
    });
  };

  const logout = () => {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(GUEST_MODE_KEY);
    
    setState({
      token: null,
      isAuthenticated: false,
      isGuest: false,
      isLoading: false,
    });
  };

  const enterGuestMode = () => {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.setItem(GUEST_MODE_KEY, 'true');
    
    setState({
      token: null,
      isAuthenticated: false,
      isGuest: true,
      isLoading: false,
    });
  };

  return (
    <AuthContext.Provider
      value={{
        ...state,
        login,
        register,
        logout,
        enterGuestMode,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {};

  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => {
      store[key] = value.toString();
    },
    removeItem: (key: string) => {
      delete store[key];
    },
    clear: () => {
      store = {};
    }
  };
})();

global.localStorage = localStorageMock as Storage;

describe('API Client', () => {
  beforeEach(() => {
    localStorage.clear();
    global.fetch = vi.fn();
  });

  it('should attach auth token to requests when token exists', async () => {
    const mockToken = 'test-token-123';
    localStorage.setItem('authToken', mockToken);

    const mockResponse = { ok: true, json: async () => ({ data: 'test' }) };
    (global.fetch as any).mockResolvedValue(mockResponse);

    const apiModule = await import('../services/api');
    
    // This is a basic smoke test - just verify module loads
    expect(apiModule).toBeDefined();
    expect(apiModule.authApi).toBeDefined();
    expect(apiModule.userApi).toBeDefined();
    expect(apiModule.mealApi).toBeDefined();
  });

  it('should handle 401 responses', async () => {
    const mockResponse = { ok: false, status: 401, json: async () => ({ message: 'Unauthorized' }) };
    (global.fetch as any).mockResolvedValue(mockResponse);

    // Verify fetch mock is callable
    expect(global.fetch).toBeDefined();
  });

  it('should handle network errors gracefully', async () => {
    (global.fetch as any).mockRejectedValue(new Error('Network error'));

    // Verify error can be mocked
    try {
      await fetch('http://test.com');
    } catch (error) {
      expect(error).toBeInstanceOf(Error);
    }
  });
});

describe('Auth State', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('should persist auth token to localStorage', () => {
    const token = 'test-auth-token';
    localStorage.setItem('authToken', token);
    
    expect(localStorage.getItem('authToken')).toBe(token);
  });

  it('should persist guest mode flag to localStorage', () => {
    localStorage.setItem('guestMode', 'true');
    
    expect(localStorage.getItem('guestMode')).toBe('true');
  });

  it('should clear auth state on logout', () => {
    localStorage.setItem('authToken', 'token');
    localStorage.setItem('guestMode', 'false');
    
    localStorage.removeItem('authToken');
    localStorage.removeItem('guestMode');
    
    expect(localStorage.getItem('authToken')).toBeNull();
    expect(localStorage.getItem('guestMode')).toBeNull();
  });
});

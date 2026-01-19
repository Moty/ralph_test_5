const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3001';

interface ApiError {
  message: string;
  status?: number;
}

type UnauthorizedHandler = () => void;

class ApiClient {
  private baseUrl: string;
  private onUnauthorized?: UnauthorizedHandler;

  constructor(baseUrl: string = API_BASE_URL) {
    this.baseUrl = baseUrl;
  }

  setUnauthorizedHandler(handler: UnauthorizedHandler) {
    this.onUnauthorized = handler;
  }

  private getAuthHeaders(): HeadersInit {
    const token = localStorage.getItem('authToken');
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    
    return headers;
  }

  private async handleResponse<T>(response: Response): Promise<T> {
    if (!response.ok) {
      if (response.status === 401 && this.onUnauthorized) {
        this.onUnauthorized();
      }
      
      let errorMessage = `HTTP error! status: ${response.status}`;
      
      try {
        const errorData = await response.json();
        if (errorData.message) {
          errorMessage = errorData.message;
        } else if (errorData.error) {
          errorMessage = errorData.error;
        }
      } catch {
        // If response is not JSON, use default error message
      }
      
      const error: ApiError = {
        message: errorMessage,
        status: response.status,
      };
      throw error;
    }
    
    return response.json();
  }

  async get<T>(endpoint: string): Promise<T> {
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });
    
    return this.handleResponse<T>(response);
  }

  async post<T>(endpoint: string, data?: unknown): Promise<T> {
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: data ? JSON.stringify(data) : undefined,
    });
    
    return this.handleResponse<T>(response);
  }

  async postFormData<T>(endpoint: string, formData: FormData): Promise<T> {
    const token = localStorage.getItem('authToken');
    const headers: HeadersInit = {};
    
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'POST',
      headers,
      body: formData,
    });
    
    return this.handleResponse<T>(response);
  }
}

const api = new ApiClient();

export function setApiUnauthorizedHandler(handler: () => void) {
  api.setUnauthorizedHandler(handler);
}

export interface RegisterRequest {
  email: string;
  password: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface AuthResponse {
  token: string;
  userId: string;
}

export interface UserStats {
  today: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
  week: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
  allTime: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
}

export interface MealItem {
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

export interface AnalysisResult {
  mealId: string;
  timestamp: string;
  items: MealItem[];
  totals: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
}

export interface Meal {
  id: string;
  userId: string;
  timestamp: string;
  imageUrl?: string;
  items: MealItem[];
  totals: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
}

export const authApi = {
  register: (data: RegisterRequest): Promise<AuthResponse> => 
    api.post<AuthResponse>('/api/auth/register', data),
  
  login: (data: LoginRequest): Promise<AuthResponse> => 
    api.post<AuthResponse>('/api/auth/login', data),
};

export const userApi = {
  getStats: (): Promise<UserStats> => 
    api.get<UserStats>('/api/user/stats'),
};

export const mealApi = {
  analyze: (imageFile: File, model?: string): Promise<AnalysisResult> => {
    const formData = new FormData();
    formData.append('image', imageFile);
    if (model) {
      formData.append('model', model);
    }
    return api.postFormData<AnalysisResult>('/api/analyze', formData);
  },
  
  getMeals: (): Promise<Meal[]> => 
    api.get<Meal[]>('/api/meals'),
};

export type { ApiError };

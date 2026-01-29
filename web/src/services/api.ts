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

  private getAuthHeaders(includeContentType: boolean = true): HeadersInit {
    const token = localStorage.getItem('authToken');
    const headers: HeadersInit = {};
    
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    
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

  async delete<T>(endpoint: string): Promise<T> {
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'DELETE',
      headers: this.getAuthHeaders(false),  // No Content-Type for DELETE without body
    });

    return this.handleResponse<T>(response);
  }

  async put<T>(endpoint: string, data?: unknown): Promise<T> {
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method: 'PUT',
      headers: this.getAuthHeaders(),
      body: data ? JSON.stringify(data) : undefined,
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
  name: string;
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
    count: number;
    avgCalories: number;
    totalCalories: number;
    totalProtein: number;
    totalCarbs: number;
    totalFat: number;
  };
  week: {
    count: number;
    avgCalories: number;
    totalCalories: number;
    totalProtein: number;
    totalCarbs: number;
    totalFat: number;
  };
  allTime: {
    count: number;
    avgCalories: number;
    totalCalories: number;
    totalProtein: number;
    totalCarbs: number;
    totalFat: number;
  };
  hasProfile: boolean;
  dietInfo?: {
    dietType: string;
    dietName: string;
    goals: {
      dailyCalories: number;
      dailyProtein: number;
      dailyCarbs: number;
      dailyFat: number;
      dailyFiber?: number;
      dailySugarLimit?: number;
    };
    todayCompliance: {
      isOnTrack: boolean;
      carbsCompliance: number;
      proteinCompliance: number;
      fatCompliance: number;
      overallCompliance: number;
      issues: string[];
      suggestions: string[];
    };
  };
}

// Diet Profile Types
export interface DietTemplate {
  dietType: string;
  name: string;
  description: string;
  proteinRatio: number;
  carbsRatio: number;
  fatRatio: number;
  baselineCalories: number;
  baselineProtein: number;
  baselineCarbs: number;
  baselineFat: number;
  fiberMinimum?: number;
  sugarMaximum?: number;
}

export interface UserProfile {
  id: string;
  userId: string;
  dietType: string;
  dailyCalorieGoal: number;
  dailyProteinGoal: number;
  dailyCarbsGoal: number;
  dailyFatGoal: number;
  dailyFiberGoal?: number;
  dailySugarLimit?: number;
  weight?: number;
  height?: number;
  age?: number;
  gender?: 'male' | 'female';
  activityLevel?: 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';
  dietaryRestrictions: string[];
}

export interface ProfileResponse {
  profile: UserProfile;
  template: {
    name: string;
    description: string;
    proteinRatio?: number;
    carbsRatio?: number;
    fatRatio?: number;
  };
}

export interface ProfileUpdateData {
  dietType?: string;
  dailyCalorieGoal?: number;
  dailyProteinGoal?: number;
  dailyCarbsGoal?: number;
  dailyFatGoal?: number;
  dailyFiberGoal?: number;
  dailySugarLimit?: number;
  weight?: number;
  height?: number;
  age?: number;
  gender?: 'male' | 'female';
  activityLevel?: 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';
  dietaryRestrictions?: string[];
}

export interface CalculateGoalsRequest {
  weight: number;
  height: number;
  age: number;
  gender: 'male' | 'female';
  activityLevel: 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';
  dietType: string;
}

export interface CalculateGoalsResponse {
  goals: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
  template: {
    name: string;
    description: string;
  };
}

// Progress Types
export interface DailyProgress {
  id: string;
  date: string;
  totalCalories: number;
  totalProtein: number;
  totalCarbs: number;
  totalFat: number;
  totalFiber: number;
  totalSugar: number;
  goalCalories: number;
  goalProtein: number;
  goalCarbs: number;
  goalFat: number;
  goalFiber?: number;
  goalSugar?: number;
  mealCount: number;
  carbsCompliance: number;
  proteinCompliance: number;
  fatCompliance: number;
  isOnTrack: boolean;
  netCarbs?: number;
}

export interface RemainingBudget {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber?: number;
  sugar?: number;
}

export interface MealSuggestion {
  type: string;
  description: string;
  targetCalories: number;
  targetProtein: number;
  targetCarbs: number;
  targetFat: number;
}

export interface TodayProgressResponse {
  progress: DailyProgress;
  remaining: RemainingBudget;
  suggestions: string[];
  dietType: string;
  template: DietTemplate;
}

export interface WeeklySummary {
  id: string;
  weekStart: string;
  avgCalories: number;
  avgProtein: number;
  avgCarbs: number;
  avgFat: number;
  totalMeals: number;
  daysTracked: number;
  complianceRate: number;
  bestDay?: string;
  worstDay?: string;
}

export interface WeekProgressResponse {
  weekStart: string;
  weekEnd: string;
  days: DailyProgress[];
  summary: WeeklySummary;
  dietType: string;
}

export interface MonthlyProgressResponse {
  weeks: WeeklySummary[];
  summary: {
    totalWeeks: number;
    avgComplianceRate: number;
    trend: 'improving' | 'declining' | 'stable';
  };
  dietType: string;
}

// Ketone Types
export interface KetoneLog {
  id: string;
  ketoneLevel: number;
  measurementType: string;
  notes?: string;
  timestamp: string;
}

export interface KetosisStatus {
  isInKetosis: boolean;
  level: 'none' | 'light' | 'moderate' | 'optimal' | 'high';
  message: string;
}

export interface KetoneLogResponse {
  log: KetoneLog;
  ketosisStatus: KetosisStatus;
}

export interface KetoneStats {
  avgLevel: number;
  minLevel: number;
  maxLevel: number;
  daysInKetosis: number;
  totalDays: number;
  ketosisRate: number;
  trend: 'improving' | 'declining' | 'stable' | 'none';
}

export interface KetoneRecentResponse {
  logs: KetoneLog[];
  stats: KetoneStats;
}

export interface MealItem {
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

export interface FoodItem {
  name: string;
  portion: string;
  nutrition: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
  confidence: number;
}

export interface AnalysisResult {
  id?: string;
  timestamp: string;
  foods: FoodItem[];
  totals: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
}

export interface Meal {
  id: string;
  timestamp: string;
  thumbnail?: string | null;
  imageUrl?: string;
  foods?: Array<{
    name: string;
    portion: string;
    nutrition: {
      calories: number;
      protein: number;
      carbs: number;
      fat: number;
    };
    confidence: number;
  }>;
  items?: MealItem[];
  totals: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
}

interface MealsResponse {
  meals: Meal[];
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

export const profileApi = {
  getProfile: (): Promise<ProfileResponse> =>
    api.get<ProfileResponse>('/api/profile'),

  updateProfile: (data: ProfileUpdateData): Promise<ProfileResponse> =>
    api.post<ProfileResponse>('/api/profile', data),

  getDietTemplates: (): Promise<{ templates: DietTemplate[] }> =>
    api.get<{ templates: DietTemplate[] }>('/api/diet-templates'),

  calculateGoals: (data: CalculateGoalsRequest): Promise<CalculateGoalsResponse> =>
    api.post<CalculateGoalsResponse>('/api/profile/calculate-goals', data),
};

export const progressApi = {
  getToday: (): Promise<TodayProgressResponse> =>
    api.get<TodayProgressResponse>('/api/progress/today'),

  getWeek: (): Promise<WeekProgressResponse> =>
    api.get<WeekProgressResponse>('/api/progress/week'),

  getMonthly: (): Promise<MonthlyProgressResponse> =>
    api.get<MonthlyProgressResponse>('/api/progress/monthly'),

  getRange: (start: string, end: string): Promise<{ days: DailyProgress[] }> =>
    api.get<{ days: DailyProgress[] }>(`/api/progress/range?start=${start}&end=${end}`),
};

export const ketoneApi = {
  log: (ketoneLevel: number, measurementType?: string, notes?: string): Promise<KetoneLogResponse> =>
    api.post<KetoneLogResponse>('/api/ketone', { ketoneLevel, measurementType, notes }),

  getRecent: (limit?: number): Promise<KetoneRecentResponse> =>
    api.get<KetoneRecentResponse>(`/api/ketone/recent${limit ? `?limit=${limit}` : ''}`),

  getLatest: (): Promise<{ log: KetoneLog | null; ketosisStatus: KetosisStatus | null }> =>
    api.get<{ log: KetoneLog | null; ketosisStatus: KetosisStatus | null }>('/api/ketone/latest'),

  delete: (id: string): Promise<{ success: boolean }> =>
    api.delete<{ success: boolean }>(`/api/ketone/${id}`),
};

export interface MealUpdateRequest {
  foods?: Array<{
    name: string;
    portion: string;
    nutrition: {
      calories: number;
      protein: number;
      carbs: number;
      fat: number;
    };
    confidence?: number;
  }>;
  totals?: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  };
  timestamp?: string;
}

export const mealApi = {
  analyze: (imageFile: File, model?: string): Promise<AnalysisResult> => {
    const formData = new FormData();
    formData.append('image', imageFile);
    if (model) {
      formData.append('model', model);
    }
    return api.postFormData<AnalysisResult>('/api/analyze', formData);
  },
  
  getMeals: async (): Promise<Meal[]> => {
    const response = await api.get<MealsResponse>('/api/meals');
    return response.meals || [];
  },

  deleteMeal: (id: string): Promise<{ success: boolean; message?: string }> =>
    api.delete<{ success: boolean; message?: string }>(`/api/meals/${id}`),

  updateMeal: (id: string, data: MealUpdateRequest): Promise<Meal> =>
    api.put<Meal>(`/api/meals/${id}`, data),
};

export type { ApiError };

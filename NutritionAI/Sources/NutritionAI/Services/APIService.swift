import Foundation
#if canImport(UIKit)
import UIKit

public enum APIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case timeout
    case noImageData
    case noInternetConnection
    case unauthorized
}

public class APIService {
    private let session: URLSession
    private let settings = SettingsManager.shared
    public var authService: AuthService?
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    private func addAuthHeader(to request: inout URLRequest) async {
        print("[APIService] addAuthHeader called, authService is \(authService == nil ? "nil" : "set")")
        if let token = await authService?.getToken() {
            print("[APIService] Got token, adding Authorization header")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("[APIService] No token available")
        }
    }
    
    private func handleUnauthorized() {
        Task { @MainActor in
            // Don't logout guest users - they're expected to have no token
            if authService?.isGuest == true {
                print("[APIService] Ignoring 401 for guest user")
                return
            }
            authService?.logout()
        }
    }
    
    /// Register a new user
    func register(email: String, password: String, name: String) async throws -> (token: String, user: User) {
        guard let url = URL(string: "\(settings.backendURL)/api/auth/register") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password, "name": name]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            return (authResponse.token, authResponse.user)
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Registration failed")
        }
    }
    
    /// Login with email and password
    func login(email: String, password: String) async throws -> (token: String, user: User) {
        guard let url = URL(string: "\(settings.backendURL)/api/auth/login") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            return (authResponse.token, authResponse.user)
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Login failed")
        }
    }
    
    /// Fetch user statistics
    func fetchUserStats() async throws -> UserStats {
        guard let url = URL(string: "\(settings.backendURL)/api/user/stats") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            handleUnauthorized()
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 200 {
            let stats = try JSONDecoder().decode(UserStats.self, from: data)
            return stats
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Failed to fetch stats")
        }
    }
    
    /// Analyzes a food image and returns nutrition data
    /// - Parameter image: UIImage to analyze
    /// - Returns: MealAnalysis with nutrition breakdown
    /// - Throws: APIError if request fails
    func analyzeImage(_ image: UIImage) async throws -> MealAnalysis {
        guard let url = URL(string: "\(settings.backendURL)/api/analyze") else {
            throw APIError.invalidURL
        }
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.noImageData
        }
        
        // Create multipart/form-data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        await addAuthHeader(to: &request)
        
        var body = Data()
        
        // Add model parameter to body
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append(settings.geminiModel.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add image data to body
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                handleUnauthorized()
                throw APIError.unauthorized
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let mealAnalysis = try decoder.decode(MealAnalysis.self, from: data)
                    return mealAnalysis
                } catch {
                    throw APIError.decodingError(error)
                }
            case 400, 500:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw APIError.serverError(errorResponse.error)
                } else {
                    throw APIError.serverError("Server error: \(httpResponse.statusCode)")
                }
            default:
                throw APIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            if error.code == .timedOut {
                throw APIError.timeout
            } else if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw APIError.noInternetConnection
            } else {
                throw APIError.networkError(error)
            }
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    /// Fetch all meals for the current user
    func fetchMeals() async throws -> [CloudMeal] {
        guard let url = URL(string: "\(settings.backendURL)/api/meals") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        await addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            handleUnauthorized()
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let mealsResponse = try decoder.decode(CloudMealsResponse.self, from: data)
            return mealsResponse.meals
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Failed to fetch meals")
        }
    }
}

// Helper struct for cloud meals response
public struct CloudMealsResponse: Codable {
    public let meals: [CloudMeal]
}

public struct CloudMeal: Codable {
    public let id: String
    public let thumbnail: String?
    public let foods: [CloudFood]
    public let totals: CloudTotals
    public let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, thumbnail, foods, totals, timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        foods = try container.decodeIfPresent([CloudFood].self, forKey: .foods) ?? []
        totals = try container.decode(CloudTotals.self, forKey: .totals)
        
        // Handle timestamp as either Date or String
        if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else if let dateString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                timestamp = date
            } else {
                // Try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                timestamp = formatter.date(from: dateString) ?? Date()
            }
        } else {
            timestamp = Date()
        }
    }
}

public struct CloudFood: Codable {
    public let name: String
    public let portion: String
    public let nutrition: CloudNutrition
    public let confidence: Double
}

public struct CloudNutrition: Codable {
    public let calories: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let fiber: Double?
    
    enum CodingKeys: String, CodingKey {
        case calories, protein, carbs, fat, fiber
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle both Int and Double from JSON
        if let intVal = try? container.decode(Int.self, forKey: .calories) {
            calories = Double(intVal)
        } else {
            calories = try container.decodeIfPresent(Double.self, forKey: .calories) ?? 0
        }
        if let intVal = try? container.decode(Int.self, forKey: .protein) {
            protein = Double(intVal)
        } else {
            protein = try container.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        }
        if let intVal = try? container.decode(Int.self, forKey: .carbs) {
            carbs = Double(intVal)
        } else {
            carbs = try container.decodeIfPresent(Double.self, forKey: .carbs) ?? 0
        }
        if let intVal = try? container.decode(Int.self, forKey: .fat) {
            fat = Double(intVal)
        } else {
            fat = try container.decodeIfPresent(Double.self, forKey: .fat) ?? 0
        }
        if let intVal = try? container.decode(Int.self, forKey: .fiber) {
            fiber = Double(intVal)
        } else {
            fiber = try container.decodeIfPresent(Double.self, forKey: .fiber)
        }
    }
}

public struct CloudTotals: Codable {
    public let calories: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let fiber: Double?
    
    enum CodingKeys: String, CodingKey {
        case calories, protein, carbs, fat, fiber
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle both Int and Double from JSON
        if let intVal = try? container.decode(Int.self, forKey: .calories) {
            calories = Double(intVal)
        } else {
            calories = try container.decodeIfPresent(Double.self, forKey: .calories) ?? 0
        }
        if let intVal = try? container.decode(Int.self, forKey: .protein) {
            protein = Double(intVal)
        } else {
            protein = try container.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        }
        if let intVal = try? container.decode(Int.self, forKey: .carbs) {
            carbs = Double(intVal)
        } else {
            carbs = try container.decodeIfPresent(Double.self, forKey: .carbs) ?? 0
        }
        if let intVal = try? container.decode(Int.self, forKey: .fat) {
            fat = Double(intVal)
        } else {
            fat = try container.decodeIfPresent(Double.self, forKey: .fat) ?? 0
        }
        if let intVal = try? container.decode(Int.self, forKey: .fiber) {
            fiber = Double(intVal)
        } else {
            fiber = try container.decodeIfPresent(Double.self, forKey: .fiber)
        }
    }
}

// Helper struct for error responses
private struct ErrorResponse: Codable {
    let error: String
}

// Helper struct for auth responses
private struct AuthResponse: Codable {
    let token: String
    let user: User
}

#endif

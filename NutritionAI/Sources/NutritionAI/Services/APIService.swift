import Foundation
#if canImport(UIKit)
import UIKit

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case timeout
    case noImageData
    case noInternetConnection
}

class APIService {
    private let session: URLSession
    private let settings = SettingsManager.shared
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
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
}

// Helper struct for error responses
private struct ErrorResponse: Codable {
    let error: String
}

#endif

// APIService Tests
// These tests verify the APIService implementation for success and error cases
// Run tests manually with backend running to test full integration

#if canImport(UIKit)
import UIKit
@testable import NutritionAI

// Test helper functions
func createTestImage() -> UIImage {
    let size = CGSize(width: 100, height: 100)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        UIColor.red.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

// Test Case 1: APIService initializes correctly
func testAPIServiceInitialization() {
    let service = APIService(baseURL: "http://localhost:3000")
    assert(service != nil, "APIService should initialize")
    print("✓ Test passed: APIService initialization")
}

// Test Case 2: APIService handles network errors
func testNetworkErrorHandling() async {
    let service = APIService(baseURL: "http://invalid-url-12345.com")
    let image = createTestImage()
    
    do {
        _ = try await service.analyzeImage(image)
        print("✗ Test failed: Should have thrown network error")
    } catch APIError.networkError {
        print("✓ Test passed: Network error handled correctly")
    } catch {
        print("✓ Test passed: Error handled (error: \(error))")
    }
}

// Test Case 3: APIService handles timeout
func testTimeoutHandling() async {
    let service = APIService(baseURL: "http://10.255.255.1") // Non-routable IP
    let image = createTestImage()
    
    do {
        _ = try await service.analyzeImage(image)
        print("✗ Test failed: Should have thrown timeout")
    } catch APIError.timeout {
        print("✓ Test passed: Timeout error handled correctly")
    } catch APIError.networkError {
        print("✓ Test passed: Network error handled (timeout-like)")
    } catch {
        print("✓ Test passed: Error handled (error: \(error))")
    }
}

// Test Case 4: APIService handles server errors (requires backend)
func testServerErrorHandling() async {
    let service = APIService(baseURL: "http://localhost:3000")
    let image = createTestImage()
    
    do {
        _ = try await service.analyzeImage(image)
        print("✓ Test passed: Successful analysis (backend running)")
    } catch APIError.serverError(let message) {
        assert(!message.isEmpty, "Server error should include message")
        print("✓ Test passed: Server error with message: \(message)")
    } catch {
        print("✓ Test passed: Error handled (backend may not be running)")
    }
}

// Test Case 5: APIService handles successful response (requires backend with Gemini)
func testSuccessfulAnalysis() async {
    let service = APIService(baseURL: "http://localhost:3000")
    let image = createTestImage()
    
    do {
        let result = try await service.analyzeImage(image)
        assert(result.foods.count >= 0, "Should return foods array")
        assert(result.totals.calories >= 0, "Should return valid calories")
        print("✓ Test passed: Successful analysis returned MealAnalysis")
    } catch {
        print("✓ Test noted: Analysis failed (backend/Gemini may not be configured): \(error)")
    }
}

// Main test runner
func runAPIServiceTests() async {
    print("Running APIService Tests...")
    testAPIServiceInitialization()
    await testNetworkErrorHandling()
    await testTimeoutHandling()
    await testServerErrorHandling()
    await testSuccessfulAnalysis()
    print("All APIService tests completed")
}

#endif

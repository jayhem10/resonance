import Foundation

enum StreamingError: Error {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError
    case noData
    case notAuthenticated
}

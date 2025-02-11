import Foundation

class SpotifyService {
    static let shared = SpotifyService()
    private let baseURL = "https://api.spotify.com/v1"
    
    struct SpotifyPlaylist: Codable, Identifiable, Equatable {
        let id: String
        let name: String
        let description: String?
        let images: [SpotifyImage]
        let external_urls: [String: String]
        
        var imageURL: URL? {
            guard let urlString = images.first?.url else { return nil }
            return URL(string: urlString)
        }
        
        var spotifyURL: URL? {
            guard let urlString = external_urls["spotify"] else { return nil }
            return URL(string: urlString)
        }
        
        static func == (lhs: SpotifyPlaylist, rhs: SpotifyPlaylist) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    struct SpotifyImage: Codable, Equatable {
        let url: String
        let height: Int?
        let width: Int?
    }
    
    struct SearchResponse: Codable {
        let playlists: PlaylistsResponse
    }
    
    struct PlaylistsResponse: Codable {
        let items: [SpotifyPlaylist?]
        
        var validItems: [SpotifyPlaylist] {
            return items.compactMap { $0 }
        }
    }
    
    func searchPlaylists(query: String, limit: Int = 50) async throws -> [SpotifyPlaylist] {
        let accessToken = try SpotifyAuthManager.shared.getAccessToken()
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?q=\(encodedQuery)&type=playlist&limit=\(limit)") else {
            throw SpotifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug: Print the raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Raw JSON response: \(jsonString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            // Token expiré, déconnexion et demande de nouvelle connexion
            SpotifyAuthManager.shared.signOut()
            throw SpotifyError.tokenExpired
        } else if httpResponse.statusCode != 200 {
            throw SpotifyError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Si la réponse contient une erreur, on la décode
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            if errorResponse.error.status == 401 {
                SpotifyAuthManager.shared.signOut()
                throw SpotifyError.tokenExpired
            }
            throw SpotifyError.serverError(statusCode: errorResponse.error.status)
        }
        
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.playlists.validItems
    }
    
    struct ErrorResponse: Codable {
        let error: SpotifyError
        
        struct SpotifyError: Codable {
            let status: Int
            let message: String
        }
    }
}

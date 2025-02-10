import Foundation
import AuthenticationServices
import SwiftUI

enum SpotifyError: Error {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError
    case noData
}

class SpotifyAuthManager {
    static let shared = SpotifyAuthManager()
    
    private let clientID = "89e1aac201964c03959db0557b4efe86" // À remplir avec votre Client ID Spotify
    private let clientSecret = "fbc7e31573e5426d842b4a750e9e23be" // À remplir avec votre Client Secret Spotify
    private let redirectURI = "moodify://callback"
    
    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "spotify_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "spotify_access_token") }
    }
    
    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "spotify_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "spotify_refresh_token") }
    }
    
    var tokenExpirationDate: Date? {
        get { UserDefaults.standard.object(forKey: "spotify_token_expiration_date") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "spotify_token_expiration_date") }
    }
    
    var isSignedIn: Bool {
        return accessToken != nil
    }
    
    func getAuthURL() -> URL? {
        let scopes = "playlist-read-private playlist-read-collaborative user-library-read"
        let base = "https://accounts.spotify.com/authorize"
        let string = "\(base)?response_type=code&client_id=\(clientID)&scope=\(scopes)&redirect_uri=\(redirectURI)&show_dialog=true"
        return URL(string: string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
    }
    
    @MainActor
    func authenticate() async {
        guard let url = getAuthURL() else {
            print("Failed to create auth URL")
            return
        }
        
        let webAuthView = WebAuthView(
            url: url,
            callbackURLScheme: "moodify"
        ) { [weak self] code in
            Task {
                do {
                    try await self?.exchangeCodeForToken(code: code)
                } catch {
                    print("Failed to exchange code for token: \(error.localizedDescription)")
                }
            }
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let hostingController = UIHostingController(rootView: webAuthView)
            window.rootViewController?.present(hostingController, animated: true)
        }
    }
    
    func exchangeCodeForToken(code: String) async throws {
        let base = "https://accounts.spotify.com/api/token"
        guard let url = URL(string: base) else { throw SpotifyError.invalidURL }
        
        let bodyParameters = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "client_secret": clientSecret
        ]
        
        let bodyString = bodyParameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        self.accessToken = result.access_token
        self.refreshToken = result.refresh_token
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(result.expires_in))
    }
}

struct AuthResponse: Codable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String?
    let scope: String
    let token_type: String
}

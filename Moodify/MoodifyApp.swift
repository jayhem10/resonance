import SwiftUI

@main
struct MoodifyApp: App {
    @StateObject private var authManager = SpotifyAuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isSignedIn {
                MoodPlaylistView()
            } else {
                LoginView()
            }
        }
    }
}

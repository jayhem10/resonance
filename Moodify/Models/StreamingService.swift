import SwiftUI

enum StreamingService: String {
    case spotify = "Spotify"
    
    var iconName: String {
        switch self {
        case .spotify: return "music.note"
        }
    }
    
    var color: String {
        switch self {
        case .spotify: return "1DB954" // Spotify green
        }
    }
}

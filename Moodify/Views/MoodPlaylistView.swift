import SwiftUI

struct MoodPlaylistView: View {
    @State private var selectedMood: Mood = .happy
    @State private var playlists: [SpotifyService.SpotifyPlaylist] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingLogin = false
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    enum Mood: String, CaseIterable {
        case happy = "Happy"
        case chill = "Chill"
        case energetic = "Energetic"
        case melancholic = "Melancholic"
        case romantic = "Romantic"
        case focused = "Focused"
        
        var icon: String {
            switch self {
            case .happy: return "face.smiling"
            case .chill: return "leaf"
            case .energetic: return "bolt"
            case .melancholic: return "cloud.rain"
            case .romantic: return "heart"
            case .focused: return "brain.head.profile"
            }
        }
        
        var searchTerm: String {
            switch self {
            case .happy: return "happy upbeat playlist"
            case .chill: return "chill relaxing playlist"
            case .energetic: return "energetic workout playlist"
            case .melancholic: return "melancholic sad playlist"
            case .romantic: return "romantic love songs playlist"
            case .focused: return "focus study playlist"
            }
        }
        
        var gradient: [Color] {
            switch self {
            case .happy: return [.yellow, .orange]
            case .chill: return [.mint, .teal]
            case .energetic: return [.red, .orange]
            case .melancholic: return [.purple, .blue]
            case .romantic: return [.pink, .red]
            case .focused: return [.blue, .cyan]
            }
        }
    }
    
    var filteredPlaylists: [SpotifyService.SpotifyPlaylist] {
        if searchText.isEmpty {
            return playlists
        }
        return playlists.filter { playlist in
            playlist.name.lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: selectedMood.gradient),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Mood Selection
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(Mood.allCases, id: \.self) { mood in
                                    MoodButton(mood: mood,
                                             isSelected: mood == selectedMood,
                                             action: {
                                                 selectedMood = mood
                                                 Task {
                                                     await fetchPlaylists(for: mood)
                                                 }
                                             })
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Rechercher une playlist...", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()
                        } else if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.white)
                                .padding()
                        } else {
                            // Results count
                            Text("\(filteredPlaylists.count) playlists trouvées")
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            // Playlists Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 20),
                                GridItem(.flexible(), spacing: 20)
                            ], spacing: 20) {
                                ForEach(filteredPlaylists) { playlist in
                                    PlaylistCard(playlist: playlist)
                                        .onTapGesture {
                                            openInSpotify(playlist)
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Mood Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "person.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .task {
                await fetchPlaylists(for: selectedMood)
            }
            .fullScreenCover(isPresented: $showingLogin) {
                LoginView()
            }
        }
    }
    
    private func fetchPlaylists(for mood: Mood) async {
        isLoading = true
        errorMessage = nil
        searchText = "" // Reset search when changing mood
        
        guard SpotifyAuthManager.shared.isSignedIn else {
            showingLogin = true
            isLoading = false
            return
        }
        
        do {
            let playlists = try await SpotifyService.shared.searchPlaylists(query: mood.searchTerm, limit: 50)
            await MainActor.run {
                self.playlists = playlists
                isLoading = false
            }
        } catch let error as SpotifyError {
            await MainActor.run {
                switch error {
                case .invalidURL:
                    errorMessage = "URL invalide"
                case .invalidResponse:
                    errorMessage = "Réponse invalide du serveur"
                case .serverError(let statusCode):
                    errorMessage = "Erreur serveur: \(statusCode)"
                case .decodingError:
                    errorMessage = "Erreur de décodage des données"
                case .noData:
                    errorMessage = "Aucune donnée reçue"
                case .noAccessToken:
                    showingLogin = true
                    errorMessage = "Veuillez vous connecter à Spotify"
                case .tokenExpired:
                    showingLogin = true
                    errorMessage = "Votre session a expiré, veuillez vous reconnecter"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Erreur: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func openInSpotify(_ playlist: SpotifyService.SpotifyPlaylist) {
        guard let url = playlist.spotifyURL else { return }
        UIApplication.shared.open(url)
    }
}

struct MoodButton: View {
    let mood: MoodPlaylistView.Mood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: mood.icon)
                    .font(.system(size: 24))
                Text(mood.rawValue)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .frame(width: 80, height: 80)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(isSelected ? 1 : 0), lineWidth: 2)
            )
        }
    }
}

struct PlaylistCard: View {
    let playlist: SpotifyService.SpotifyPlaylist
    
    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: playlist.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(height: 120)
            .cornerRadius(8)
            
            Text(playlist.name)
                .font(.headline)
                .lineLimit(2)
            
            if let description = playlist.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 3)
    }
}

struct MoodPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        MoodPlaylistView()
    }
}

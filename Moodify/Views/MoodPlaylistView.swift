import SwiftUI

struct MoodPlaylistView: View {
    @State private var selectedMood: Mood = .happy
    @State private var playlists: [SpotifyService.SpotifyPlaylist] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingLogin = false
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
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
    
    var body: some View {
        NavigationView {
            MainContentView(
                selectedMood: $selectedMood,
                playlists: playlists,
                isLoading: isLoading,
                errorMessage: errorMessage,
                showingLogin: $showingLogin,
                searchText: $searchText,
                onFetchPlaylists: fetchPlaylists,
                onOpenSpotify: openInSpotify
            )
        }
    }
    
    private func fetchPlaylists(for mood: Mood) async {
        isLoading = true
        errorMessage = nil
        searchText = ""
        
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
                handleError(error)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Erreur: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func handleError(_ error: SpotifyError) {
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
    }
    
    private func openInSpotify(_ playlist: SpotifyService.SpotifyPlaylist) {
        guard let url = playlist.spotifyURL else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Subviews
struct MainContentView: View {
    @Binding var selectedMood: MoodPlaylistView.Mood
    let playlists: [SpotifyService.SpotifyPlaylist]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var showingLogin: Bool
    @Binding var searchText: String
    @State private var showingProfile = false
    let onFetchPlaylists: (MoodPlaylistView.Mood) async -> Void
    let onOpenSpotify: (SpotifyService.SpotifyPlaylist) -> Void
    
    private var filteredPlaylists: [SpotifyService.SpotifyPlaylist] {
        if searchText.isEmpty { return playlists }
        return playlists.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resonance")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Trouvez la playlist parfaite pour votre humeur")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: { showingProfile = true }) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(spacing: 25) {
                        MoodSelectionView(selectedMood: $selectedMood, onFetchPlaylists: onFetchPlaylists)
                        SearchBarView(searchText: $searchText)
                        
                        if isLoading {
                            LoadingView()
                        } else if let error = errorMessage {
                            ErrorView(message: error)
                        } else {
                            ResultsCountView(count: filteredPlaylists.count)
                            PlaylistsGridView(playlists: filteredPlaylists, onOpenSpotify: onOpenSpotify)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingProfile) {
            ProfileView(isPresented: $showingProfile, showingLogin: $showingLogin)
        }
        .task { await onFetchPlaylists(selectedMood) }
        .fullScreenCover(isPresented: $showingLogin) { LoginView() }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: selectedMood.gradient),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 16))
            
            TextField("Rechercher une playlist...", text: $searchText)
                .foregroundColor(.white)
                .accentColor(.white)
                .font(.system(size: 16))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 16))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .padding(.horizontal)
    }
}

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}

struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .padding()
            Text(message)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .padding()
    }
}

struct ResultsCountView: View {
    let count: Int
    
    var body: some View {
        HStack {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(count > 1 ? "playlists trouvées" : "playlist trouvée")
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

struct PlaylistsGridView: View {
    let playlists: [SpotifyService.SpotifyPlaylist]
    let onOpenSpotify: (SpotifyService.SpotifyPlaylist) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(playlists) { playlist in
                PlaylistCard(playlist: playlist)
                    .onTapGesture { onOpenSpotify(playlist) }
            }
        }
        .padding()
    }
}

struct MoodButton: View {
    let mood: MoodPlaylistView.Mood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mood.icon)
                    .font(.system(size: 28))
                Text(mood.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .frame(width: 85, height: 85)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(isSelected ? 1 : 0), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct PlaylistCard: View {
    let playlist: SpotifyService.SpotifyPlaylist
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                AsyncImage(url: playlist.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: 140)
                        .clipped()
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.3)
                        ProgressView()
                    }
                }
                .frame(height: 140)
                .cornerRadius(15, antialiased: true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    
                    if let description = playlist.description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 180, height: 250)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct MoodSelectionView: View {
    @Binding var selectedMood: MoodPlaylistView.Mood
    let onFetchPlaylists: (MoodPlaylistView.Mood) async -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(MoodPlaylistView.Mood.allCases, id: \.self) { mood in
                    MoodButton(
                        mood: mood,
                        isSelected: mood == selectedMood,
                        action: {
                            withAnimation {
                                selectedMood = mood
                            }
                            Task {
                                await onFetchPlaylists(mood)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ProfileView: View {
    @Binding var isPresented: Bool
    @Binding var showingLogin: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 25) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("Mon Compte")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    VStack(spacing: 15) {
                        Button(action: {
                            SpotifyAuthManager.shared.signOut()
                            showingLogin = true
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Se déconnecter")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(15)
                        }
                        
                        Button(action: { dismiss() }) {
                            Text("Fermer")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

struct MoodPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        MoodPlaylistView()
    }
}

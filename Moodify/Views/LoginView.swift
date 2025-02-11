import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentGradient = 0
    
    let gradients: [[Color]] = [
        MoodPlaylistView.Mood.happy.gradient,
        MoodPlaylistView.Mood.chill.gradient,
        MoodPlaylistView.Mood.energetic.gradient,
        MoodPlaylistView.Mood.melancholic.gradient,
        MoodPlaylistView.Mood.romantic.gradient,
        MoodPlaylistView.Mood.focused.gradient
    ]
    
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Fond animé
            LinearGradient(
                gradient: Gradient(colors: gradients[currentGradient]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2), value: currentGradient)
            .onReceive(timer) { _ in
                withAnimation {
                    currentGradient = (currentGradient + 1) % gradients.count
                }
            }
            
            // Effet de verre
            VStack {
                Spacer()
                
                VStack(spacing: 30) {
                    Text("Bienvenue sur Moodify")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Connectez-vous avec votre service de streaming préféré")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .padding()
                    
                    Button(action: {
                        Task {
                            await SpotifyAuthManager.shared.authenticate()
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: StreamingService.spotify.iconName)
                                .font(.title3)
                            Text("Se connecter avec \(StreamingService.spotify.rawValue)")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(30)
                .padding()
                
                Spacer()
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}

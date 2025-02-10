import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to Moodify")
                    .font(.largeTitle)
                    .padding()
                
                Text("Your music mood companion")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Moodify")
        }
    }
}

#Preview {
    ContentView()
}

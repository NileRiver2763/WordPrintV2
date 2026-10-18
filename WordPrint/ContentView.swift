import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    var body: some View {
        TabView {
            CheckInFlowView()
                .tabItem {
                    Label("Check-in", systemImage: "mic.circle.fill")
                }

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.bar.fill")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
        }
        .tint(.cyan)
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenIntro },
            set: { if !$0 { hasSeenIntro = true } }
        )) {
            OnboardingView { hasSeenIntro = true }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CheckIn.self, Session.self], inMemory: true)
}

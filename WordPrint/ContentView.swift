import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    init() {
        // Rounded, heavy navigation titles to match the rest of the app.
        func rounded(_ style: UIFont.TextStyle, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
            return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 0) } ?? base
        }
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: rounded(.largeTitle, .heavy)]
        bar.titleTextAttributes = [.font: rounded(.headline, .bold)]
    }

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

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
        }
        .tint(Color(red: 0.08, green: 0.58, blue: 0.22))
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

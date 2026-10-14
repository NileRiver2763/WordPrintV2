import SwiftUI

struct ContentView: View {
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CheckIn.self, Session.self], inMemory: true)
}

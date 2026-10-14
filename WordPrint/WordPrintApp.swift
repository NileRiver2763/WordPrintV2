import SwiftUI
import SwiftData

@main
struct WordPrintApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [CheckIn.self, Session.self])
    }
}

import SwiftUI
import SwiftData

/// Every saved check-in, newest first. Swipe a row to delete it.
struct HistoryView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if checkIns.isEmpty && sessions.isEmpty {
                    emptyState
                } else {
                    List {
                        rows
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private var rows: some View {
        if !sessions.isEmpty {
            Section {
                sectionTitle("Voice Check-ins")
                ForEach(sessions) { session in
                    SessionRow(session: session)
                        .modifier(HistoryCard())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(session)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        if !checkIns.isEmpty {
            Section {
                sectionTitle("All Check-ins")
                ForEach(checkIns) { item in
                    CheckInRow(checkIn: item)
                        .modifier(HistoryCard())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.title2, design: .rounded, weight: .heavy))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 2, trailing: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.08, green: 0.58, blue: 0.22).opacity(0.10))
                    .frame(width: 120, height: 120)
                Image(systemName: "list.bullet")
                    .font(.system(size: 52))
                    .foregroundStyle(Color(red: 0.08, green: 0.58, blue: 0.22))
            }
            VStack(spacing: 10) {
                Text("No check-ins yet")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                Text("Your past check-ins will\nappear here.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

/// A raised white card for one list row.
private struct HistoryCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .chunkyBorder(20)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [CheckIn.self, Session.self], inMemory: true)
}

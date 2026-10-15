import SwiftUI
import SwiftData

//Author: Neil Voore

private let trendsPrimary = Color(red: 0.27, green: 0.24, blue: 0.80)
private let trendsPurple  = Color(red: 0.56, green: 0.27, blue: 0.68)

struct TrendsView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    var body: some View {
        NavigationStack {
            Group {
                if checkIns.isEmpty && sessions.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryBanner
                if !checkIns.isEmpty { weekGrid }
                if !sessions.isEmpty { sessionsSection }
                if !checkIns.isEmpty { historySection }
            }
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Summary Banner

    private var summaryBanner: some View {
        HStack(spacing: 0) {
            statCell(value: "\(checkIns.count + sessions.count)", label: "Total\nEntries",  color: trendsPrimary)
            Divider().frame(height: 52)
            statCell(value: "\(currentStreak())",                 label: "Day\nStreak",     color: Color(red: 0.10, green: 0.73, blue: 0.53))
            Divider().frame(height: 52)
            let top = mostFrequentMood()
            statCell(value: top.emoji,                            label: "Top\nMood",       color: trendsPurple)
        }
        .padding(.vertical, 18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 7-Day Grid

    struct DayEntry {
        let date: Date
        let shortLabel: String
        let isToday: Bool
        let checkIn: CheckIn?
    }

    private var weekGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Last 7 Days")
                .font(.title2.bold())
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                ForEach(last7Days(), id: \.date) { day in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(day.checkIn != nil
                                      ? colorForMood(day.checkIn!.mood).opacity(0.18)
                                      : Color(.tertiarySystemGroupedBackground))
                                .frame(width: 48, height: 54)

                            if let ci = day.checkIn {
                                Text(ci.emoji).font(.system(size: 28))
                            } else {
                                Image(systemName: "minus")
                                    .font(.callout)
                                    .foregroundStyle(.quaternary)
                            }
                        }

                        Text(day.shortLabel)
                            .font(.caption.bold())
                            .foregroundStyle(day.isToday ? trendsPrimary : .secondary)

                        Circle()
                            .fill(day.isToday ? trendsPrimary : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    // MARK: - Voice Sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Voice Check-ins")
                .font(.title2.bold())
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    Divider().padding(.leading, 76)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("All Check-ins")
                .font(.title2.bold())
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(checkIns) { item in
                    CheckInRow(checkIn: item)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    Divider().padding(.leading, 92)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(trendsPrimary.opacity(0.10))
                    .frame(width: 120, height: 120)
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(trendsPrimary)
            }
            VStack(spacing: 10) {
                Text("No check-ins yet")
                    .font(.title2.bold())
                Text("Start by tapping the Check-in tab\nand recording how you feel.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Helpers

    private func last7Days() -> [DayEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today) ?? today
            let ci  = checkIns.first { calendar.isDate($0.date, inSameDayAs: day) }
            return DayEntry(
                date: day,
                shortLabel: day.formatted(.dateTime.weekday(.abbreviated)),
                isToday: calendar.isDateInToday(day),
                checkIn: ci
            )
        }
    }

    private func currentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var day = calendar.startOfDay(for: .now)
        while checkIns.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) != nil {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    private func mostFrequentMood() -> (label: String, emoji: String) {
        let counts = Dictionary(grouping: checkIns, by: \.mood).mapValues(\.count)
        if let top = counts.max(by: { $0.value < $1.value }),
           let ci  = checkIns.first(where: { $0.mood == top.key }) {
            return (top.key, ci.emoji)
        }
        return ("—", "—")
    }
}

// MARK: - Color helper (file-level so CheckInRow can use it)

func colorForMood(_ mood: String) -> Color {
    switch mood {
    case "Great":  return Color(red: 0.10, green: 0.73, blue: 0.53)
    case "Good":   return Color(red: 0.15, green: 0.52, blue: 0.83)
    case "Okay":   return Color(red: 0.91, green: 0.52, blue: 0.14)
    case "Low":    return Color(red: 0.42, green: 0.25, blue: 0.82)
    case "Tired":  return Color(red: 0.58, green: 0.28, blue: 0.58)
    default:       return .gray
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.27, green: 0.24, blue: 0.80).opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: "mic.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.27, green: 0.24, blue: 0.80))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if !session.emoji.isEmpty {
                        Text(session.emoji).font(.title3)
                        Text(session.mood.isEmpty ? "Voice Check-in" : session.mood)
                            .font(.title3.bold())
                    } else {
                        Text("Voice Check-in")
                            .font(.title3.bold())
                    }
                    Spacer()
                    Text(session.formattedDuration)
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.27, green: 0.24, blue: 0.80))
                        .clipShape(Capsule())
                }

                Text(session.date, format: .dateTime.weekday(.wide).month(.wide).day().year())
                    .font(.body)
                    .foregroundStyle(.secondary)

                if !session.transcript.isEmpty {
                    Text(session.transcript)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Row

struct CheckInRow: View {
    let checkIn: CheckIn

    var body: some View {
        HStack(spacing: 16) {
            Text(checkIn.emoji)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(colorForMood(checkIn.mood).opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 5) {
                Text(checkIn.mood)
                    .font(.title3.bold())

                Text(checkIn.date, format: .dateTime.weekday(.wide).month(.wide).day().year())
                    .font(.body)
                    .foregroundStyle(.secondary)

                if !checkIn.note.isEmpty {
                    Text(checkIn.note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }
}

#Preview {
    TrendsView()
        .modelContainer(for: [CheckIn.self, Session.self], inMemory: true)
}

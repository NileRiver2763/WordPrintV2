import SwiftUI
import SwiftData
import Charts

//Author: Neil Voore

private let trendsPrimary = Color(red: 0.08, green: 0.58, blue: 0.22)
private let trendsPurple  = Color(red: 0.95, green: 0.68, blue: 0.0)

struct TrendsView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Environment(\.modelContext) private var modelContext
    // Cached: fingerprinting runs NLP over every transcript, so don't redo it on each redraw.
    @State private var drift = DriftAnalysis(sessions: [])
    @State private var showShareSheet = false

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
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Content

    private var content: some View {
        List {
            chartsRows
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showShareSheet) { ShareWithDoctorSheet(drift: drift) }
        .task(id: sessions.map(\.date)) {
            // Language analysis is slow; do it off the main thread so saving never stalls the UI.
            let snapshots = sessions.map(SessionSnapshot.init)
            let result = await Task.detached(priority: .userInitiated) { DriftAnalysis(snapshots: snapshots) }.value
            if !Task.isCancelled { drift = result }
        }
    }

    // MARK: - Cards

    @ViewBuilder private var chartsRows: some View {
        summaryBanner
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        if !checkIns.isEmpty {
            weekGrid
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        if !sessions.isEmpty {
            speechPatternsSection
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    // MARK: - Speech Patterns

    private var speechPatternsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Speech Patterns")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .padding(.horizontal, 20)

            if !drift.hasBaseline {
                let have = drift.points.count
                let need = DriftAnalysis.minCheckIns - have
                Text("Your personal baseline appears after \(DriftAnalysis.minCheckIns) voice check-ins of at least \(DriftAnalysis.minWords) words. \(have == 0 ? "Record" : "Record \(need) more") to get started.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                if drift.isFlagged { driftNote(drift) }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(drift.availableFeatures) { feature in
                        FeatureChart(feature: feature, drift: drift)
                    }
                }
                .padding(.horizontal, 16)

                Button {
                    showShareSheet = true
                } label: {
                    SunnyShareLabel()
                }
                .buttonStyle(ChunkyButtonStyle(face: Chunky.orange, lip: Chunky.orangeLip, radius: 20, depth: 6))
                .padding(.horizontal, 16)

                Text("Shaded band = your usual range (baseline ± 1.5 standard deviations, from your first \(drift.baselineSize) check-ins). Dashed line = your average.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .chunkyBorder(24)
        .padding(.horizontal, 16)
    }

    private func driftNote(_ drift: DriftAnalysis) -> some View {
        let names = drift.shifted.map { "\($0.feature.title.lowercased()) (\($0.higher ? "higher" : "lower"))" }
            .formatted(.list(type: .and))
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(Color(red: 0.91, green: 0.52, blue: 0.14))
            VStack(alignment: .leading, spacing: 4) {
                Text("A gentle heads-up")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text("Your last two check-ins sounded a little different from your usual: \(names). Sleep, stress, a cold, or a different topic can all do this. It's only a pattern, not a diagnosis. If it keeps up and you're curious, it may be worth mentioning to a doctor.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(red: 0.91, green: 0.52, blue: 0.14).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
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
        .chunkyBorder(24)
        .padding(.horizontal, 16)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.footnote, design: .rounded, weight: .bold))
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
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .padding(.horizontal, 20)

            HStack(spacing: 6) {
                ForEach(last7Days(), id: \.date) { day in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(day.checkIn != nil
                                      ? colorForMood(day.checkIn!.mood).opacity(0.18)
                                      : Color(.tertiarySystemGroupedBackground))
                                .frame(maxWidth: 48)
                                .frame(height: 54)

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
        .chunkyBorder(24)
        .padding(.horizontal, 16)
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
                    .font(.system(.title2, design: .rounded, weight: .heavy))
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
        Streak.count(dates: checkIns.map(\.date) + sessions.map(\.date))
    }

    private func mostFrequentMood() -> (label: String, emoji: String) {
        // Voice sessions carry a mood too; skip ones recorded without one.
        let moods = checkIns.map { ($0.mood, $0.emoji) }
            + sessions.filter { !$0.mood.isEmpty }.map { ($0.mood, $0.emoji) }
        let counts = Dictionary(grouping: moods, by: \.0).mapValues(\.count)
        if let top = counts.max(by: { $0.value < $1.value }),
           let match = moods.first(where: { $0.0 == top.key }) {
            return (top.key, match.1)
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
    case "Low":    return Color(red: 0.25, green: 0.45, blue: 0.75)
    case "Tired":  return Color(red: 0.55, green: 0.55, blue: 0.10)
    default:       return .gray
    }
}

// MARK: - Feature chart

struct FeatureChart: View {
    let feature: FingerprintFeature
    let drift: DriftAnalysis
    /// Smaller type and height, for the one-page PDF.
    var compact = false

    private static let calm = Color(red: 0.08, green: 0.58, blue: 0.22)
    private static let note = Color(red: 0.91, green: 0.52, blue: 0.14)

    var body: some View {
        let b = drift.baseline[feature]
        let lo = b.map { $0.mean - DriftAnalysis.zThreshold * $0.sd }
        let hi = b.map { $0.mean + DriftAnalysis.zThreshold * $0.sd }
        let values = drift.points.compactMap { feature.value(in: $0.fingerprint) }
        let yMin = min(values.min() ?? 0, lo ?? .infinity)
        let yMax = max(values.max() ?? 1, hi ?? -.infinity)
        let pad = max((yMax - yMin) * 0.1, 0.01)
        let first = drift.points.first?.date ?? .now
        let last = max(drift.points.last?.date ?? .now, first.addingTimeInterval(3600))

        VStack(alignment: .leading, spacing: 4) {
            Text(feature.title)
                .font(compact ? .system(size: 10, weight: .bold) : .subheadline.bold())
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(feature.unit.isEmpty ? " " : feature.unit)
                .font(compact ? .system(size: 7) : .caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)

            Chart {
                if let b, let lo, let hi {
                    RectangleMark(xStart: .value("From", first), xEnd: .value("To", last),
                                  yStart: .value("Low", lo), yEnd: .value("High", hi))
                        .foregroundStyle(Self.calm.opacity(0.14))
                    RuleMark(y: .value("Average", b.mean))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Self.calm.opacity(0.5))
                }
                ForEach(drift.points) { p in
                    if let v = feature.value(in: p.fingerprint) {
                        let outside = !p.inBaseline && abs(p.zScores[feature] ?? 0) > DriftAnalysis.zThreshold
                        LineMark(x: .value("Date", p.date), y: .value(feature.title, v))
                            .foregroundStyle(Self.calm.opacity(0.6))
                        PointMark(x: .value("Date", p.date), y: .value(feature.title, v))
                            .foregroundStyle(outside ? Self.note : Self.calm)
                            .symbolSize(30)
                    }
                }
            }
            .chartYScale(domain: (yMin - pad)...(yMax + pad))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisValueLabel().font(.caption2)
                }
            }
            .frame(height: compact ? 60 : 90)
        }
        .padding(compact ? 6 : 10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.08, green: 0.58, blue: 0.22).opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: "mic.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.08, green: 0.58, blue: 0.22))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if !session.emoji.isEmpty {
                        Text(session.emoji).font(.title3)
                        Text(session.mood.isEmpty ? "Voice Check-in" : session.mood)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    } else {
                        Text("Voice Check-in")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    Spacer()
                    Text(session.formattedDuration)
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.08, green: 0.58, blue: 0.22))
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
                    .font(.system(.title3, design: .rounded, weight: .bold))

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

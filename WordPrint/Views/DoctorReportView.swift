import SwiftUI
import Charts

// ── Plain-English notes ───────────────────────

extension FingerprintFeature {
    /// One-line explanation a non-specialist can follow.
    var plainDescription: String {
        switch self {
        case .typeTokenRatio:     return "How many different words you use, compared with how many you say in total."
        case .movingAverageTTR:   return "The same word-variety measure, taken in fixed 50-word chunks so longer recordings aren't unfairly scored."
        case .vagueLanguageIndex: return "How often vague words (\"thing\", \"stuff\", \"it\") stand in for specific ones."
        case .fillerRate:         return "Filler words such as \"um\", \"uh\" and \"like\", per 100 words."
        case .wordsPerMinute:     return "How fast you speak."
        case .meanSentenceLength: return "The average number of words in a sentence."
        case .pronounNounRatio:   return "How often pronouns (\"it\", \"that\") are used compared with naming things directly."
        case .pausesPerMinute:    return "How many pauses of half a second or longer happen mid-speech, per minute. Measured from the microphone's loudness, so it is approximate."
        case .meanPauseSeconds:   return "How long those pauses last on average, in seconds."
        }
    }
}

struct FeatureNote: Identifiable {
    let feature: FingerprintFeature
    let text: String
    var id: String { feature.rawValue }
}

enum ReportNotes {
    /// How the latest check-in compares with the person's own usual, in words.
    static func status(z: Double) -> String {
        let size = abs(z)
        let direction = z >= 0 ? "higher" : "lower"
        if size < 1 { return "close to your usual" }
        if size <= DriftAnalysis.zThreshold { return "a little \(direction) than usual" }
        return "noticeably \(direction) than usual"
    }

    private static func format(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func featureNotes(for drift: DriftAnalysis) -> [FeatureNote] {
        guard let latest = drift.points.last else { return [] }
        return FingerprintFeature.allCases.compactMap { feature in
            guard let b = drift.baseline[feature], let z = latest.zScores[feature] else { return nil }
            let unit = feature.unit.isEmpty ? "" : " \(feature.unit)"
            guard let latestValue = feature.value(in: latest.fingerprint) else { return nil }
            let text = "Latest \(format(latestValue))\(unit), "
                + "your usual is about \(format(b.mean))\(unit): \(status(z: z))."
            return FeatureNote(feature: feature, text: text)
        }
    }

    static func summary(for drift: DriftAnalysis) -> String {
        let n = drift.points.count
        if drift.isFlagged {
            let names = drift.shifted.map { "\($0.feature.title.lowercased()) (\($0.higher ? "higher" : "lower"))" }
                .formatted(.list(type: .and))
            return "Across \(n) voice check-ins, the two most recent both sounded a little different from this person's usual in several ways at once: \(names). "
                + "Everyday things such as poor sleep, stress, a cold or a different topic can cause this, so it is a prompt for a conversation, not a finding."
        }
        return "Across \(n) voice check-ins, the most recent ones are within this person's usual range. No pattern of change was detected."
    }

    static let howToRead = "Each small chart shows one measurement over time. The shaded band is the person's own usual range, taken from their first check-ins; the dashed line is their average. Orange dots are outside that range."

    static let disclaimer = "WordPrint does not diagnose any condition. It only tracks how a person's speech changes compared with their own earlier check-ins. All data was recorded and analysed on the person's phone."
}

/// Bright sunshine-orange "Share with doctor" button face.
struct SunnyShareLabel: View {
    var body: some View {
        Label("Share with doctor", systemImage: "square.and.arrow.up")
            .font(.system(size: 21, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
    }
}

enum ReportColors {
    static let indigo = Color(red: 0.08, green: 0.58, blue: 0.22)
    static let purple = Color(red: 0.95, green: 0.68, blue: 0.0)
    static let sun    = Color(red: 1.0, green: 0.78, blue: 0.1)
}

// ── The one-page report ───────────────────────

/// Fixed US-Letter page (612 × 792 pt), always drawn in light mode so it prints well.
struct DoctorReportView: View {
    static let pageSize = CGSize(width: 612, height: 792)

    let name: String
    let drift: DriftAnalysis
    var generated: Date = .now

    private var displayName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var rangeText: String {
        guard let first = drift.points.first?.date, let last = drift.points.last?.date else { return "—" }
        let f = { (d: Date) in d.formatted(date: .abbreviated, time: .omitted) }
        return first == last ? f(first) : "\(f(first)) – \(f(last))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Text(ReportNotes.summary(for: drift))
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReportColors.sun.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: drift.availableFeatures.count > 8 ? 5 : 4), spacing: 8) {
                ForEach(drift.availableFeatures) { feature in
                    FeatureChart(feature: feature, drift: drift, compact: true)
                }
            }
            Text(ReportNotes.howToRead)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 5) {
                Text("What each measurement means").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ReportColors.indigo)
                ForEach(ReportNotes.featureNotes(for: drift)) { note in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(note.feature.title).font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(ReportColors.purple)
                        Text(note.feature.plainDescription + " " + note.text)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
            Text(ReportNotes.disclaimer)
                .font(.system(size: 8, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReportColors.sun.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(36)
        .frame(width: Self.pageSize.width, height: Self.pageSize.height, alignment: .topLeading)
        .foregroundStyle(.black)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("☀️").font(.system(size: 34))
            VStack(alignment: .leading, spacing: 3) {
                Text("WordPrint speech summary").font(.system(size: 20, weight: .bold))
                Text(displayName.isEmpty ? "Name not provided" : displayName).font(.system(size: 13, weight: .semibold))
                Text("Check-ins: \(rangeText)  •  \(drift.points.count) voice check-ins")
                    .font(.system(size: 10)).opacity(0.9)
            }
            Spacer()
            Text("Prepared \(generated.formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 9)).opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [ReportColors.indigo, ReportColors.purple],
                           startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// ── PDF creation ──────────────────────────────

enum ReportPDF {
    /// Renders the report to a one-page PDF in the temp folder and returns its URL.
    @MainActor
    static func make(name: String, drift: DriftAnalysis) -> URL? {
        let renderer = ImageRenderer(content: DoctorReportView(name: name, drift: drift))
        renderer.proposedSize = ProposedViewSize(DoctorReportView.pageSize)

        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WordPrint-Summary-\(stamp).pdf")
        var box = CGRect(origin: .zero, size: DoctorReportView.pageSize)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }

        var drew = false
        renderer.render { size, draw in
            context.beginPDFPage(nil)
            context.translateBy(x: (box.width - size.width) / 2, y: (box.height - size.height) / 2)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            drew = true
        }
        return drew ? url : nil
    }
}

// ── Share sheet ───────────────────────────────

struct ShareWithDoctorSheet: View {
    let drift: DriftAnalysis

    @AppStorage("reportName") private var name = ""
    @State private var pdfURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 12) {
                        NeilbotAvatar(size: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ready to share! ☀️")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(ReportColors.indigo)
                            Text("Here is your summary for the doctor.")
                                .font(.title3)
                        }
                        Spacer(minLength: 0)
                    }

                    TextField("Your name (shown on the summary)", text: $name)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)

                    DoctorReportView(name: name, drift: drift)
                        .scaleEffect(0.5, anchor: .topLeading)
                        .frame(width: DoctorReportView.pageSize.width / 2,
                               height: DoctorReportView.pageSize.height / 2,
                               alignment: .topLeading)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                        .accessibilityLabel("Preview of the one-page summary")

                    if let pdfURL {
                        ShareLink(item: pdfURL, preview: SharePreview("WordPrint summary", image: Image(systemName: "doc.richtext"))) {
                            SunnyShareLabel()
                        }
                        .buttonStyle(ChunkyButtonStyle(face: Chunky.orange, lip: Chunky.orangeLip, radius: 20, depth: 6))
                    } else {
                        ProgressView("Preparing PDF…")
                    }

                    Text("The PDF is made on your phone. Nothing leaves it until you pick where to send it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .background(
                LinearGradient(colors: [ReportColors.sun.opacity(0.35), Color(.systemBackground)],
                               startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            )
            .navigationTitle("Share with doctor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            // Rebuild the PDF when the name changes (short pause so typing isn't laggy).
            .task(id: name) {
                pdfURL = nil   // never offer a PDF that has the old name on it
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                pdfURL = ReportPDF.make(name: name, drift: drift)
            }
        }
    }
}

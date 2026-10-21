import SwiftUI
import SwiftData

//Author: Neil Voore
// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Flow phase
// ─────────────────────────────────────────────────────────────────────────────

enum FlowPhase {
    case welcome
    case requestingPermissions
    case denied(title: String, message: String)
    case recording
    case saved(duration: TimeInterval, transcript: String)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CheckInFlowView
// ─────────────────────────────────────────────────────────────────────────────

private let flowMoods: [MoodOption] = [
    MoodOption(emoji: "😄", label: "Great", color: Color(red: 0.10, green: 0.73, blue: 0.53)),
    MoodOption(emoji: "🙂", label: "Good",  color: Color(red: 0.15, green: 0.52, blue: 0.83)),
    MoodOption(emoji: "😐", label: "Okay",  color: Color(red: 0.91, green: 0.52, blue: 0.14)),
    MoodOption(emoji: "😔", label: "Low",   color: Color(red: 0.25, green: 0.45, blue: 0.75)),
    MoodOption(emoji: "😴", label: "Tired", color: Color(red: 0.55, green: 0.55, blue: 0.10)),
]

struct CheckInFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speech = SpeechRecognizer()

    @State private var phase: FlowPhase = .welcome
    @State private var secondsElapsed: Int = 0
    @State private var sessionTimer: Timer?
    @State private var selectedMood: MoodOption?
    @State private var period = TimeOfDay.from(date: .now)
    @AppStorage(Neilbot.nameKey) private var patientName = ""
    @AppStorage("reminderOn") private var reminderOn = false
    @Query private var allSessions: [Session]
    @Query private var allCheckIns: [CheckIn]
    @State private var showPDF = false
    @State private var promptInUse = DailyPrompt.forCheckIn(number: 0)
    @Environment(\.scenePhase) private var scenePhase

    private let maxSeconds = 60

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                switch phase {
                case .welcome:                             welcomeScreen
                case .requestingPermissions:               permissionSpinner
                case .denied(let title, let message):      deniedScreen(title: title, message: message)
                case .recording:                           recordingScreen
                case .saved(let dur, let tx):              savedScreen(duration: dur, transcript: tx)
                }
            }
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Welcome
    // ─────────────────────────────────────────────────────────────────────

    private var welcomeScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                NeilbotAvatar(size: 100)
                    .padding(.top, 8)

                neilbotSpeech
                    .padding(.horizontal, 16)

                moodPickerRow
            }
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom) {
            startButton
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
        }
        // Keep the greeting right if the screen is revisited later in the day.
        .onAppear {
            period = TimeOfDay.from(date: .now)
            if reminderOn {
                let m = UserDefaults.standard.object(forKey: "reminderMinutes") as? Int ?? 540
                Task { await ReminderScheduler.schedule(hour: m / 60, minute: m % 60, name: patientName) }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { period = TimeOfDay.from(date: .now) }
        }
    }

    /// The question for the next voice check-in: one step further along the list each time.
    private var nextPrompt: DailyPrompt { DailyPrompt.forCheckIn(number: allSessions.count) }

    private var neilbotSpeech: some View {
        NeilbotBubble(showsAvatar: false) {
            if Neilbot.cleanName(patientName).isEmpty {
                Text(Neilbot.askName)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                TextField("Your name", text: $patientName)
                    .textContentType(.givenName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
            } else {
                Text("\(period.greetingWord)!")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Text(Neilbot.ready)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(red: 0.40, green: 0.62, blue: 0.0))
            }
        }
    }

    private var moodPickerRow: some View {
        HStack(spacing: 8) {
            ForEach(flowMoods) { mood in
                let picked = selectedMood?.id == mood.id
                Button {
                    // No animation here: the highlight change is instant and cheap.
                    selectedMood = picked ? nil : mood
                } label: {
                    VStack(spacing: 4) {
                        Text(mood.emoji).font(.system(size: 34))
                        Text(mood.label)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(picked ? mood.color : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(ChunkyButtonStyle(
                    face: Color(.secondarySystemGroupedBackground),
                    lip: picked ? mood.color.opacity(0.7) : Chunky.gray,
                    border: picked ? mood.color : Chunky.gray,
                    radius: 16, depth: 4))
                .accessibilityLabel(mood.label)
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .padding(.horizontal, 16)
    }

    private var startButton: some View {
        Button {
            Task { await requestAndStart() }
        } label: {
            Label("Speak", systemImage: "mic.fill")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
        }
        .buttonStyle(ChunkyButtonStyle(radius: 20, depth: 6))
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Requesting permissions spinner
    // ─────────────────────────────────────────────────────────────────────

    private var permissionSpinner: some View {
        VStack(spacing: 28) {
            ProgressView()
                .scaleEffect(2.2)
                .tint(Color(red: 0.08, green: 0.58, blue: 0.22))
            Text("Setting up microphone…")
                .font(.system(.title2, design: .rounded, weight: .heavy))
            Text("We'll ask for permission to use\nyour microphone and speech recognition.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Permission denied
    // ─────────────────────────────────────────────────────────────────────

    private func deniedScreen(title: String, message: String) -> some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.10))
                    .frame(width: 120, height: 120)
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            }
            .buttonStyle(ChunkyButtonStyle())
            .padding(.horizontal, 32)

            Button("Go Back") { phase = .welcome }
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Recording
    // ─────────────────────────────────────────────────────────────────────

    private var recordingScreen: some View {
        ScrollView {
        VStack(spacing: 0) {
            promptCard
                .padding(.horizontal, 20)
                .padding(.top, 12)

            // Countdown ring + mic animation
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 10)
                    .frame(width: 180, height: 180)
                // Progress ring — drains as time passes
                Circle()
                    .trim(from: 0,
                          to: max(0, CGFloat(maxSeconds - secondsElapsed) / CGFloat(maxSeconds)))
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.08, green: 0.58, blue: 0.22),
                                                Color(red: 0.95, green: 0.68, blue: 0.0)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: secondsElapsed)

                VStack(spacing: 6) {
                    Text("\(maxSeconds - secondsElapsed)")
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.08, green: 0.58, blue: 0.22))
                    Text("seconds left")
                        .font(.callout.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 20)

            PulsingMic()
                .frame(width: 90, height: 90)
                .padding(.top, 20)

            if let mood = selectedMood {
                HStack(spacing: 8) {
                    Text(mood.emoji).font(.title3)
                    Text(mood.label)
                        .font(.callout.bold())
                        .foregroundStyle(mood.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(mood.color.opacity(0.12))
                .clipShape(Capsule())
                .padding(.top, 6)
            }

            // Live transcript card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Live Transcript")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        speech.clearTranscript()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(speech.transcript.isEmpty ? Color(.tertiaryLabel) : .red)
                            .frame(width: 36, height: 36)
                            .background(
                                speech.transcript.isEmpty
                                    ? Color(.tertiarySystemGroupedBackground)
                                    : Color.red.opacity(0.10)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Clear transcript")
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(speech.transcript.isEmpty ? "Start speaking…" : speech.transcript)
                            .font(.system(size: 20))
                            .foregroundStyle(speech.transcript.isEmpty ? Color(.tertiaryLabel) : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(5)
                            .id("bottom")
                    }
                    .frame(height: 140)
                    .onChange(of: speech.transcript) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)

        }
        .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: finishRecording) {
                Label("Done — Save Check-in", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            }
            .buttonStyle(ChunkyButtonStyle(radius: 20, depth: 6))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    /// Today's question, with its picture when it is a picture prompt.
    private var promptCard: some View {
        PromptCard(prompt: promptInUse).equatable()
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Saved confirmation
    // ─────────────────────────────────────────────────────────────────────

    private func savedScreen(duration: TimeInterval, transcript: String) -> some View {
        ScrollView {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.10, green: 0.60, blue: 0.40).opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color(red: 0.10, green: 0.60, blue: 0.40))
            }

            VStack(spacing: 10) {
                Text("Check-in Saved!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                if let mood = selectedMood {
                    HStack(spacing: 8) {
                        Text(mood.emoji).font(.title2)
                        Text(mood.label)
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(mood.color)
                    }
                }
                let s = Int(duration)
                Text("You spoke for \(s / 60):\(String(format: "%02d", s % 60))")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            if !transcript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What you said:")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(transcript)
                        .font(.system(size: 18))
                        .lineSpacing(4)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            }

            GrowthCard(streak: Streak.count(dates: allSessions.map(\.date) + allCheckIns.map(\.date))) {
                showPDF = true
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ReminderRow()
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)
                .padding(.top, 12)

        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                secondsElapsed = 0
                selectedMood = nil
                phase = .welcome
            } label: {
                Text("Done")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            }
            .buttonStyle(ChunkyButtonStyle(radius: 20, depth: 6))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .sheet(isPresented: $showPDF) {
            ShareWithDoctorSheet(drift: DriftAnalysis(sessions: allSessions))
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Logic
    // ─────────────────────────────────────────────────────────────────────

    private func requestAndStart() async {
        phase = .requestingPermissions
        promptInUse = nextPrompt

        let permission = await speech.requestPermissions()
        switch permission {
        case .granted:
            do {
                try speech.startRecording()
                phase = .recording
                startSessionTimer()
            } catch {
                phase = .denied(
                    title: "Couldn't Start Microphone",
                    message: error.localizedDescription
                )
            }
        case .microphoneDenied:
            phase = .denied(
                title: "Microphone Access Needed",
                message: "WordPrint needs your microphone to hear you. Tap \"Open Settings\", then turn on Microphone for WordPrint."
            )
        case .speechDenied:
            phase = .denied(
                title: "Speech Recognition Needed",
                message: "WordPrint needs speech recognition to turn your words into text. Tap \"Open Settings\", then allow Speech Recognition for WordPrint."
            )
        case .notAvailable:
            phase = .denied(
                title: "Not Available Right Now",
                message: "Speech recognition isn't available on this device at the moment. Please try again later."
            )
        }
    }

    private func startSessionTimer() {
        secondsElapsed = 0
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            secondsElapsed += 1
            if secondsElapsed >= maxSeconds {
                finishRecording()
            }
        }
    }

    private func finishRecording() {
        sessionTimer?.invalidate()
        sessionTimer = nil

        let duration = TimeInterval(secondsElapsed)
        speech.stopRecording()

        let session = Session(
            duration: duration,
            transcript: speech.transcript,
            mood: selectedMood?.label ?? "",
            emoji: selectedMood?.emoji ?? "",
            promptID: promptInUse.id,
            pauses: speech.pauseStats
        )
        modelContext.insert(session)
        try? modelContext.save()

        phase = .saved(duration: duration, transcript: speech.transcript)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PulsingMic
// ─────────────────────────────────────────────────────────────────────────────

struct PulsingMic: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            ForEach([0.8, 0.6, 0.4] as [Double], id: \.self) { scale in
                Circle()
                    .fill(Color.red.opacity(0.15 * (1 - scale + 0.4)))
                    .scaleEffect(isPulsing ? scale + 0.25 : scale)
                    .animation(
                        .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                            .delay((1 - scale) * 0.3),
                        value: isPulsing
                    )
            }
            Image(systemName: "mic.fill")
                .font(.system(size: 28))
                .foregroundStyle(.red)
        }
        .onAppear { isPulsing = true }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────────────────────────────────────

#Preview {
    CheckInFlowView()
        .modelContainer(for: [CheckIn.self, Session.self], inMemory: true)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PromptCard
// ─────────────────────────────────────────────────────────────────────────────

/// Equatable so SwiftUI skips redrawing it every time the live transcript changes.
struct PromptCard: View, Equatable {
    let prompt: DailyPrompt

    var body: some View {
        VStack(spacing: 10) {
            if let picture = prompt.picture {
                PictureView(picture: picture)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
            }
            Text(prompt.question)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Take your time. Pauses are okay.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .chunkyBorder(20)
    }
}

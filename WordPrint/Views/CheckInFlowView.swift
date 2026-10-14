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

struct CheckInFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speech = SpeechRecognizer()

    @State private var phase: FlowPhase = .welcome
    @State private var secondsElapsed: Int = 0
    @State private var sessionTimer: Timer?

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
            .navigationBarTitleDisplayMode(.large)
            .animation(.easeInOut(duration: 0.35), value: secondsElapsed)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Welcome
    // ─────────────────────────────────────────────────────────────────────

    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            MorningSceneView()
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 6)

            VStack(spacing: 12) {
                Text("Your Daily Check-in")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Speak for up to one minute.\nTell us how you're feeling today.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)

            Spacer()

            startButton
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    private var startButton: some View {
        Button {
            Task { await requestAndStart() }
        } label: {
            Label("Start Speaking", systemImage: "mic.fill")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.27, green: 0.24, blue: 0.80),
                                 Color(red: 0.56, green: 0.27, blue: 0.68)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color(red: 0.27, green: 0.24, blue: 0.80).opacity(0.4),
                        radius: 10, y: 5)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Requesting permissions spinner
    // ─────────────────────────────────────────────────────────────────────

    private var permissionSpinner: some View {
        VStack(spacing: 28) {
            ProgressView()
                .scaleEffect(2.2)
                .tint(Color(red: 0.27, green: 0.24, blue: 0.80))
            Text("Setting up microphone…")
                .font(.title2.bold())
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
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color(red: 0.27, green: 0.24, blue: 0.80))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
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
        VStack(spacing: 0) {
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
                        LinearGradient(colors: [Color(red: 0.27, green: 0.24, blue: 0.80),
                                                Color(red: 0.56, green: 0.27, blue: 0.68)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: secondsElapsed)

                VStack(spacing: 6) {
                    Text("\(maxSeconds - secondsElapsed)")
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.27, green: 0.24, blue: 0.80))
                    Text("seconds left")
                        .font(.callout.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 36)

            PulsingMic()
                .frame(width: 90, height: 90)
                .padding(.top, 20)

            // Live transcript card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Live Transcript")
                        .font(.headline.bold())
                        .foregroundStyle(.secondary)
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

            Spacer()

            Button(action: finishRecording) {
                Label("Done — Save Check-in", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color(red: 0.10, green: 0.60, blue: 0.40))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color(red: 0.10, green: 0.60, blue: 0.40).opacity(0.4),
                            radius: 10, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Saved confirmation
    // ─────────────────────────────────────────────────────────────────────

    private func savedScreen(duration: TimeInterval, transcript: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(red: 0.10, green: 0.60, blue: 0.40).opacity(0.12))
                    .frame(width: 130, height: 130)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(red: 0.10, green: 0.60, blue: 0.40))
            }

            VStack(spacing: 10) {
                Text("Check-in Saved!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                let s = Int(duration)
                Text("You spoke for \(s / 60):\(String(format: "%02d", s % 60))")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            if !transcript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What you said:")
                        .font(.headline)
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

            Spacer()

            Button {
                secondsElapsed = 0
                phase = .welcome
            } label: {
                Text("Done")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.27, green: 0.24, blue: 0.80),
                                     Color(red: 0.56, green: 0.27, blue: 0.68)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color(red: 0.27, green: 0.24, blue: 0.80).opacity(0.4),
                            radius: 10, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .padding(.top, 20)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Logic
    // ─────────────────────────────────────────────────────────────────────

    private func requestAndStart() async {
        phase = .requestingPermissions

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

        let session = Session(duration: duration, transcript: speech.transcript)
        modelContext.insert(session)
        try? modelContext.save()

        phase = .saved(duration: duration, transcript: speech.transcript)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MorningSceneView
// ─────────────────────────────────────────────────────────────────────────────

struct MorningSceneView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Sky gradient
                LinearGradient(
                    colors: [Color(red: 0.36, green: 0.68, blue: 0.95),
                             Color(red: 0.98, green: 0.76, blue: 0.55),
                             Color(red: 0.99, green: 0.55, blue: 0.38)],
                    startPoint: .top, endPoint: .bottom
                )

                // Sun
                Circle()
                    .fill(Color(red: 1.0, green: 0.87, blue: 0.30))
                    .frame(width: w * 0.22, height: w * 0.22)
                    .blur(radius: 2)
                    .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.10).opacity(0.6), radius: 18)
                    .position(x: w * 0.72, y: h * 0.25)

                // Cloud 1
                CloudShape()
                    .fill(Color.white.opacity(0.80))
                    .frame(width: w * 0.30, height: w * 0.10)
                    .position(x: w * 0.22, y: h * 0.20)

                // Cloud 2
                CloudShape()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: w * 0.22, height: w * 0.07)
                    .position(x: w * 0.58, y: h * 0.14)

                // Far hill
                Ellipse()
                    .fill(Color(red: 0.30, green: 0.65, blue: 0.35).opacity(0.85))
                    .frame(width: w * 1.4, height: h * 0.55)
                    .position(x: w * 0.35, y: h * 0.98)

                // Near hill
                Ellipse()
                    .fill(Color(red: 0.22, green: 0.53, blue: 0.28))
                    .frame(width: w * 1.2, height: h * 0.48)
                    .position(x: w * 0.75, y: h * 1.02)

                // Ground strip
                Rectangle()
                    .fill(Color(red: 0.18, green: 0.45, blue: 0.23))
                    .frame(height: h * 0.18)
                    .frame(maxWidth: .infinity)
                    .position(x: w * 0.5, y: h * 0.91)
            }
        }
    }
}

// Simple cloud silhouette from overlapping capsules
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.addEllipse(in: CGRect(x: w*0.05, y: h*0.25, width: w*0.50, height: h*0.75))
        p.addEllipse(in: CGRect(x: w*0.30, y: h*0.05, width: w*0.40, height: h*0.70))
        p.addEllipse(in: CGRect(x: w*0.55, y: h*0.30, width: w*0.40, height: h*0.65))
        p.addRect(CGRect(x: w*0.05, y: h*0.55, width: w*0.90, height: h*0.45))
        return p
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

import SwiftUI

private let introPrimary = Color(red: 0.08, green: 0.58, blue: 0.22)

/// Shown once on first launch. Sets honest expectations before anything is recorded.
struct OnboardingView: View {
    let onContinue: () -> Void

    @AppStorage(Neilbot.nameKey) private var name = ""
    @State private var askingName = false
    @FocusState private var nameFocused: Bool

    private struct Point: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let text: String
    }

    private let points: [Point] = [
        Point(icon: "waveform", color: introPrimary,
              title: "What WordPrint does",
              text: "You record a short voice check-in. WordPrint measures simple things about how you speak, like pace, filler words and word variety."),
        Point(icon: "chart.line.uptrend.xyaxis", color: Color(red: 0.10, green: 0.60, blue: 0.40),
              title: "It tracks change over time",
              text: "After a few check-ins it learns what's usual for you, then shows if things shift. It only compares you with yourself."),
        Point(icon: "stethoscope", color: Color(red: 0.91, green: 0.52, blue: 0.14),
              title: "It does not diagnose",
              text: "WordPrint can't tell you whether anything is wrong. It is not a medical test and can't replace a doctor."),
        Point(icon: "lock.iphone", color: Color(red: 0.95, green: 0.68, blue: 0.0),
              title: "Your data stays on your phone",
              text: "Speech is turned into text on your device and only the text is saved. Nothing is uploaded. You choose if and when to share a summary."),
        Point(icon: "heart.text.square", color: Color(red: 0.80, green: 0.25, blue: 0.30),
              title: "If you are worried, talk to a doctor",
              text: "Concerns about your memory, speech or health are always worth a conversation with a doctor, whatever this app shows."),
    ]

    var body: some View {
        if askingName { nameStep } else { introPage }
    }

    private var canFinish: Bool { !Neilbot.cleanName(name).isEmpty }

    /// Last first-launch step: Neilbot asks the name once, so every later screen can use it.
    private var nameStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                NeilbotAvatar(size: 140)
                Text(Neilbot.askName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("I'll use it to greet you and on the summary you share with your doctor.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .font(.title2)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .onSubmit { if canFinish { onContinue() } }
            }
            .padding(.horizontal, 24)
            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(canFinish ? .white : Color(.systemGray))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            }
            .buttonStyle(canFinish
                ? ChunkyButtonStyle(radius: 20, depth: 6)
                : ChunkyButtonStyle(face: Color(.systemGray5), lip: Color(.systemGray4), radius: 20, depth: 6))
            .disabled(!canFinish)
            .padding(.horizontal, 24)

            Button("Skip for now", action: onContinue)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { nameFocused = true }
    }

    private var introPage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Welcome to WordPrint")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Before you start, here's what to expect.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                    ForEach(points) { point in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: point.icon)
                                .font(.system(size: 26))
                                .foregroundStyle(point.color)
                                .frame(width: 52, height: 52)
                                .background(point.color.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(point.title).font(.system(.title3, design: .rounded, weight: .bold))
                                Text(point.text)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Button { askingName = true } label: {
                Text("I understand — let's start")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            }
            .buttonStyle(ChunkyButtonStyle(radius: 20, depth: 6))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview { OnboardingView {} }

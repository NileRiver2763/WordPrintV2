import SwiftUI

private let introPrimary = Color(red: 0.27, green: 0.24, blue: 0.80)

/// Shown once on first launch. Sets honest expectations before anything is recorded.
struct OnboardingView: View {
    let onContinue: () -> Void

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
        Point(icon: "lock.iphone", color: Color(red: 0.56, green: 0.27, blue: 0.68),
              title: "Your data stays on your phone",
              text: "Speech is turned into text on your device and only the text is saved. Nothing is uploaded. You choose if and when to share a summary."),
        Point(icon: "heart.text.square", color: Color(red: 0.80, green: 0.25, blue: 0.30),
              title: "If you are worried, talk to a doctor",
              text: "Concerns about your memory, speech or health are always worth a conversation with a doctor, whatever this app shows."),
    ]

    var body: some View {
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
                                Text(point.title).font(.title3.bold())
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

            Button(action: onContinue) {
                Text("I understand — let's start")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(introPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview { OnboardingView {} }

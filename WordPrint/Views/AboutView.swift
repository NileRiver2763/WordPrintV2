import SwiftUI

private let aboutPrimary = Color(red: 0.08, green: 0.58, blue: 0.22)
private let aboutAccent  = Color(red: 0.95, green: 0.68, blue: 0.0)

//Author: Neil Voore

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 0)

                    NeilbotBubble(showsAvatar: false) {
                        Text("Hi, I'm Neilbot!")
                            .font(.system(.title, design: .rounded, weight: .heavy))
                            .accessibilityAddTraits(.isHeader)
                        Text("WordPrint is your daily check-in. Talk for a minute and I'll keep track of how you sound over time.")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(Color(red: 0.40, green: 0.62, blue: 0.0))
                    }
                    .padding(.horizontal, 16)

                    featureCards

                    ReminderRow()
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .chunkyBorder(20)
                        .padding(.horizontal, 16)

                    tipsCard

                    Text("Version 1.0  •  Made with care")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Feature Cards

    private var featureCards: some View {
        VStack(spacing: 14) {
            InfoCard(
                icon: "checkmark.circle.fill",
                iconColor: Chunky.green,
                title: "Check in every day",
                content: "Pick a face, press Speak, and talk. It only takes a minute."
            )
            InfoCard(
                icon: "chart.bar.fill",
                iconColor: aboutAccent,
                title: "Watch your trends",
                content: "See patterns over time. They can help you and your doctor."
            )
            InfoCard(
                icon: "lock.shield.fill",
                iconColor: Color(red: 0.25, green: 0.45, blue: 0.75),
                title: "Private & secure",
                content: "Everything stays on your phone unless you choose to share it."
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tips

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tips")
                .font(.system(.title2, design: .rounded, weight: .heavy))

            TipRow(number: "1", text: "Check in at the same time each day. Morning works well.")
            TipRow(number: "2", text: "Be honest. There are no wrong answers.")
            TipRow(number: "3", text: "Talk about anything: your day, a memory, what you see.")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .chunkyBorder(20)
        .padding(.horizontal, 16)
    }
}

// MARK: - InfoCard

struct InfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text(content)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .chunkyBorder(20)
    }
}

// MARK: - TipRow

struct TipRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(colors: [Color(red: 0.08, green: 0.58, blue: 0.22),
                                            Color(red: 0.95, green: 0.68, blue: 0.0)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .clipShape(Circle())

            Text(text)
                .font(.system(.body, design: .rounded, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    AboutView()
}

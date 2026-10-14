import SwiftUI

private let aboutPrimary = Color(red: 0.27, green: 0.24, blue: 0.80)
private let aboutAccent  = Color(red: 0.56, green: 0.27, blue: 0.68)

//Author: Neil Voore

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    appHeader
                    featureCards
                    tipsCard
                    Text("Version 1.0  •  Made with care")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 8)
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 34)
                    .fill(LinearGradient(colors: [aboutPrimary, aboutAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(color: aboutPrimary.opacity(0.50), radius: 18, y: 9)

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 5) {
                Text("WordPrint")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("Daily Wellness Check-in")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    // MARK: - Feature Cards

    private var featureCards: some View {
        VStack(spacing: 14) {
            InfoCard(
                icon: "checkmark.circle.fill",
                iconColor: Color(red: 0.10, green: 0.73, blue: 0.53),
                title: "Check In Every Day",
                content: "Take a moment each morning to record how you're feeling. It only takes a few seconds."
            )
            InfoCard(
                icon: "chart.bar.fill",
                iconColor: aboutPrimary,
                title: "Watch Your Trends",
                content: "See patterns in your mood over time. Noticing trends can help you and your doctor understand your well-being."
            )
            InfoCard(
                icon: "lock.shield.fill",
                iconColor: Color(red: 0.15, green: 0.52, blue: 0.83),
                title: "Private & Secure",
                content: "All your data stays on your device. Nothing is shared or sent anywhere."
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tips

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tips for Getting Started")
                .font(.title2.bold())

            TipRow(number: "1", text: "Try to check in at the same time each day — morning works well for most people.")
            TipRow(number: "2", text: "Be honest. There are no wrong answers. How you feel is always valid.")
            TipRow(number: "3", text: "Add a short note if something specific is affecting your mood.")
        }
        .padding(22)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
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
                RoundedRectangle(cornerRadius: 15)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 54, height: 54)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.bold())

                Text(content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }
}

// MARK: - TipRow

struct TipRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(colors: [Color(red: 0.27, green: 0.24, blue: 0.80),
                                            Color(red: 0.56, green: 0.27, blue: 0.68)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    AboutView()
}

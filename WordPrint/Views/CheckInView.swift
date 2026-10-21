import SwiftUI
import SwiftData

//Author: Neil Voore

struct MoodOption: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let color: Color
}
//For V2, We are suppressing these buttons. As the design evolves, we will slowly phase these out.
private let moods: [MoodOption] = [
    MoodOption(emoji: "😄", label: "Great", color: Color(red: 0.10, green: 0.73, blue: 0.53)),
    MoodOption(emoji: "🙂", label: "Good",  color: Color(red: 0.15, green: 0.52, blue: 0.83)),
    MoodOption(emoji: "😐", label: "Okay",  color: Color(red: 0.91, green: 0.52, blue: 0.14)),
    MoodOption(emoji: "😔", label: "Low",   color: Color(red: 0.25, green: 0.45, blue: 0.75)),
    MoodOption(emoji: "😴", label: "Tired", color: Color(red: 0.55, green: 0.55, blue: 0.10)),
]

private let headerTop    = Color(red: 0.08, green: 0.58, blue: 0.22)
private let headerBottom = Color(red: 0.95, green: 0.68, blue: 0.0)

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]

    @State private var selectedMood: MoodOption?
    @State private var note: String = ""
    @State private var showConfirmation = false

    private var alreadyCheckedInToday: Bool {
        checkIns.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard

                VStack(spacing: 14) {
                    ForEach(moods) { mood in
                        MoodButton(mood: mood, isSelected: selectedMood?.id == mood.id) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                selectedMood = mood
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                noteSection
                    .padding(.horizontal, 16)

                saveButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
            }
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if showConfirmation {
                ConfirmationToast(emoji: selectedMood?.emoji ?? "✅", message: "Check-in saved!")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: showConfirmation)
        .onAppear {
            if let latest = checkIns.first, Calendar.current.isDateInToday(latest.date) {
                selectedMood = moods.first { $0.label == latest.mood }
                note = latest.note
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [headerTop, headerBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 200, height: 200)
                .offset(x: 210, y: -40)

            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 130, height: 130)
                .offset(x: 268, y: 30)

            VStack(alignment: .leading, spacing: 7) {
                Text("How are you today?")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.title3)
                }
                .foregroundStyle(.white.opacity(0.88))
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 16)
        .shadow(color: headerTop.opacity(0.45), radius: 18, y: 9)
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Add a note (optional)", systemImage: "pencil.line")
                .font(.system(.title3, design: .rounded, weight: .bold))

            TextField("What's on your mind?", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .font(.title3)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button(action: saveCheckIn) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                Text(alreadyCheckedInToday ? "Update Today's Check-in" : "Save Check-in")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background {
                if selectedMood != nil {
                    LinearGradient(colors: [headerTop, headerBottom],
                                   startPoint: .leading, endPoint: .trailing)
                } else {
                    Color.gray.opacity(0.30)
                }
            }
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: selectedMood != nil ? headerTop.opacity(0.50) : .clear,
                    radius: 14, y: 7)
        }
        .disabled(selectedMood == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedMood?.id)
        .accessibilityLabel("Save check-in")
    }

    private func saveCheckIn() {
        guard let mood = selectedMood else { return }
        if let existing = checkIns.first, Calendar.current.isDateInToday(existing.date) {
            existing.mood = mood.label
            existing.emoji = mood.emoji
            existing.note = note
        } else {
            modelContext.insert(CheckIn(mood: mood.label, emoji: mood.emoji, note: note))
        }
        showConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showConfirmation = false
        }
    }
}

// MARK: - Mood Button

struct MoodButton: View {
    let mood: MoodOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(mood.emoji)
                    .font(.system(size: 44))
                    .frame(width: 64, height: 64)
                    .background(.white.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(mood.label)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                ZStack {
                    Circle()
                        .fill(isSelected ? .white : .white.opacity(0.25))
                        .frame(width: 34, height: 34)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(mood.color)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(isSelected ? mood.color : mood.color.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(.white, lineWidth: 2.5)
                }
            }
            .shadow(color: mood.color.opacity(isSelected ? 0.55 : 0.28),
                    radius: isSelected ? 14 : 7,
                    y: isSelected ? 7 : 3)
            .scaleEffect(isSelected ? 1.025 : 1.0)
        }
        .accessibilityLabel("\(mood.label) mood")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Toast

struct ConfirmationToast: View {
    let emoji: String
    let message: String

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Text(emoji).font(.title2)
                Text(message)
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 15)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
            .padding(.top, 16)
            Spacer()
        }
    }
}

#Preview {
    CheckInView()
        .modelContainer(for: CheckIn.self, inMemory: true)
}

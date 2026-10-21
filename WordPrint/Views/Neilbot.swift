import SwiftUI
import UserNotifications

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - What Neilbot says
// ─────────────────────────────────────────────────────────────────────────────

enum Neilbot {
    /// Same key the "Share with doctor" sheet uses, so the name on the PDF is the name Neilbot uses.
    static let nameKey = "reportName"

    static func cleanName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func hello(name: String) -> String {
        let n = cleanName(name)
        return n.isEmpty ? "Hi there." : "Hi \(n)."
    }

    static func greeting(name: String, period: TimeOfDay) -> String {
        let n = cleanName(name)
        return n.isEmpty ? period.greeting : "\(period.greetingWord), \(n)!"
    }

    static let ready = "How are you feeling today? Pick the face that fits, then press Speak and talk to me."
    static let askName = "I'm Neilbot. What's your name?"
}

extension TimeOfDay {
    /// "Good morning" / "Good afternoon" / "Good evening" (late night counts as evening).
    var greetingWord: String {
        switch self {
        case .morning:   return "Good morning"
        case .afternoon: return "Good afternoon"
        case .evening, .night: return "Good evening"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Plant growth (one step per day in a row)
// ─────────────────────────────────────────────────────────────────────────────

enum GrowthStage: Int, CaseIterable {
    case seedling = 1, plant, flower, fruit, basket

    var emoji: String {
        switch self {
        case .seedling: return "🌱"
        case .plant:    return "🪴"
        case .flower:   return "🌸"
        case .fruit:    return "🍎"
        case .basket:   return "🧺"
        }
    }

    var message: String {
        switch self {
        case .seedling: return "Day 1: a seedling has sprouted!"
        case .plant:    return "Day 2: it's growing into a plant!"
        case .flower:   return "Day 3: look, a flower!"
        case .fruit:    return "Day 4: the fruit is ripe!"
        case .basket:   return "Day 5: harvest time. Your PDF is ready!"
        }
    }

    var pdfReady: Bool { self == .basket }

    /// Consecutive days 1…5 map to the five stages; day 6 starts a new seed.
    /// A streak of 0 (nothing recorded) still shows the first seedling.
    static func forStreak(_ streak: Int) -> GrowthStage {
        let step = streak <= 0 ? 1 : (streak - 1) % 5 + 1
        return GrowthStage(rawValue: step)!
    }
}

enum Streak {
    /// Consecutive days with at least one entry, ending today. If nothing is
    /// recorded today yet, the streak is 0.
    static func count(dates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        var streak = 0
        var day = calendar.startOfDay(for: now)
        while days.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Daily reminder
// ─────────────────────────────────────────────────────────────────────────────

enum ReminderScheduler {
    static let identifier = "neilbot.daily"

    static func body(name: String) -> String {
        let n = Neilbot.cleanName(name)
        return n.isEmpty ? "Neilbot is waiting to hear you. Time for your check-in!"
                         : "\(n), Neilbot is waiting to hear you. Time for your check-in!"
    }

    /// Asks permission if needed, then schedules one repeating daily notification.
    /// Returns false if the user has not allowed notifications.
    @discardableResult
    static func schedule(hour: Int, minute: Int, name: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Neilbot"
        content.body = body(name: name)
        content.sound = .default

        var when = DateComponents()
        when.hour = hour
        when.minute = minute
        let request = UNNotificationRequest(
            identifier: identifier, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do { try await center.add(request); return true } catch { return false }
    }

    /// Done off the main thread: talking to the notification service can block.
    static func cancel() {
        Task.detached(priority: .utility) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }
    }
}

/// Toggle + time picker for the daily reminder.
struct ReminderRow: View {
    @AppStorage("reminderOn") private var on = false
    @AppStorage("reminderMinutes") private var minutes = 9 * 60      // minutes after midnight
    @AppStorage(Neilbot.nameKey) private var name = ""
    @State private var blocked = false

    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                minutes = (c.hour ?? 9) * 60 + (c.minute ?? 0)
            })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $on) {
                Label("Daily reminder from Neilbot", systemImage: "bell.badge.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            if on {
                DatePicker("Remind me at", selection: time, displayedComponents: .hourAndMinute)
                    .font(.body)
            }
            if blocked {
                Text("Notifications are turned off for WordPrint. Turn them on in Settings to get reminders.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        // Only react to changes the user makes. Doing this when the row first appears
        // would contact the notification service every time a check-in is saved.
        .onChange(of: on) { Task { await apply() } }
        .onChange(of: minutes) { if on { Task { await apply() } } }
    }

    private func apply() async {
        if on {
            blocked = !(await ReminderScheduler.schedule(hour: minutes / 60, minute: minutes % 60, name: name))
            if blocked { on = false }
        } else {
            ReminderScheduler.cancel()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Neilbot's face and speech bubble
// ─────────────────────────────────────────────────────────────────────────────

struct NeilbotAvatar: View {
    var size: CGFloat = 76

    var body: some View {
        Image("NeilbotDoctor")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size, alignment: .top)
            .background(LinearGradient(colors: [Color(red: 0.84, green: 0.88, blue: 0.98),
                                                Color(red: 0.93, green: 0.88, blue: 0.96)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(red: 0.08, green: 0.58, blue: 0.22).opacity(0.35), lineWidth: size * 0.03))
            .frame(width: size * 1.1, height: size * 1.1)
        .accessibilityHidden(true)
    }
}

struct NeilbotBubble<Content: View>: View {
    var showsAvatar = true
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            if showsAvatar { NeilbotAvatar() }
            VStack(alignment: .leading, spacing: 6) { content }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .chunkyBorder(20)
        }
        .accessibilityElement(children: .contain)
    }
}

/// The plant that grows with each day in a row, shown after saving.
struct GrowthCard: View {
    let streak: Int
    var onOpenPDF: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false

    var body: some View {
        let stage = GrowthStage.forStreak(streak)
        VStack(spacing: 8) {
            Text(stage.emoji)
                .font(.system(size: 64))
                .scaleEffect(popped ? 1 : 0.4)
                .onAppear {
                    if reduceMotion { popped = true }
                    else { withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { popped = true } }
                }
                .accessibilityHidden(true)
            HStack(spacing: 6) {
                ForEach(GrowthStage.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s.rawValue <= stage.rawValue ? Color(red: 0.10, green: 0.60, blue: 0.40) : Color(.tertiarySystemFill))
                        .frame(width: 10, height: 10)
                }
            }
            .accessibilityHidden(true)
            Text(stage.message)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            if stage.pdfReady {
                Button(action: onOpenPDF) {
                    Label("Open my PDF", systemImage: "doc.richtext.fill")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                        .frame(height: 48)
                }
                .buttonStyle(ChunkyButtonStyle(radius: 16, depth: 5))
            } else {
                Text("Come back tomorrow and watch it grow.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .chunkyBorder(20)
        .accessibilityElement(children: .combine)
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Chunky buttons (raised face on a solid lip that presses down)
// ─────────────────────────────────────────────────────────────────────────────

enum Chunky {
    static let green    = Color(red: 0.12, green: 0.65, blue: 0.25)
    static let greenLip = Color(red: 0.05, green: 0.42, blue: 0.15)
    static let orange    = Color(red: 1.0, green: 0.62, blue: 0.0)
    static let orangeLip = Color(red: 0.76, green: 0.40, blue: 0.0)
    static let gray = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.30, alpha: 1) : UIColor(red: 0.89, green: 0.89, blue: 0.87, alpha: 1) })
}

struct ChunkyButtonStyle: ButtonStyle {
    var face: Color = Chunky.green
    var lip: Color = Chunky.greenLip
    var border: Color? = nil
    var radius: CGFloat = 18
    var depth: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let down = configuration.isPressed
        configuration.label
            .background(face, in: shape)
            .overlay { if let border { shape.strokeBorder(border, lineWidth: 2.5) } }
            .offset(y: down ? depth - 1 : 0)
            .background { shape.fill(lip).offset(y: depth) }
            .padding(.bottom, depth)
    }
}

extension View {
    /// Soft outline plus a solid lip underneath: the same raised look as the chunky buttons, for cards.
    func chunkyBorder(_ radius: CGFloat, depth: CGFloat = 4) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return overlay(shape.strokeBorder(Chunky.gray, lineWidth: 2.5))
            .background { shape.fill(Chunky.gray).offset(y: depth) }
    }
}

import Foundation
import SwiftData

@Model
final class Session {
    var date: Date
    var duration: TimeInterval   // seconds actually recorded
    var transcript: String
    var mood: String = ""
    var emoji: String = ""

    init(date: Date = .now, duration: TimeInterval, transcript: String, mood: String = "", emoji: String = "") {
        self.date = date
        self.duration = duration
        self.transcript = transcript
        self.mood = mood
        self.emoji = emoji
    }

    var formattedDuration: String {
        let s = Int(duration)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

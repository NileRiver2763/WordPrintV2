import Foundation
import SwiftData

@Model
final class CheckIn {
    var date: Date
    var mood: String
    var emoji: String
    var note: String

    init(date: Date = .now, mood: String, emoji: String, note: String = "") {
        self.date = date
        self.mood = mood
        self.emoji = emoji
        self.note = note
    }
}

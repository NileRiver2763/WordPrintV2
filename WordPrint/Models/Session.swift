import Foundation
import SwiftData

@Model
final class Session {
    var date: Date
    var duration: TimeInterval   // seconds actually recorded
    var transcript: String
    var mood: String = ""
    var emoji: String = ""
    /// Which daily question was asked (`DailyPrompt.id`), empty for older check-ins.
    var promptID: String = ""
    /// Pause measurements; only meaningful when `pausesMeasured` is true.
    var pausesMeasured: Bool = false
    var pauseCount: Int = 0
    var pauseSeconds: Double = 0
    var longestPauseSeconds: Double = 0

    init(date: Date = .now, duration: TimeInterval, transcript: String, mood: String = "", emoji: String = "",
         promptID: String = "", pauses: PauseStats? = nil) {
        self.date = date
        self.duration = duration
        self.transcript = transcript
        self.mood = mood
        self.emoji = emoji
        self.promptID = promptID
        if let pauses {
            pausesMeasured = true
            pauseCount = pauses.count
            pauseSeconds = pauses.totalSeconds
            longestPauseSeconds = pauses.longestSeconds
        }
    }

    var pauseStats: PauseStats? {
        pausesMeasured ? PauseStats(count: pauseCount, totalSeconds: pauseSeconds, longestSeconds: longestPauseSeconds) : nil
    }

    var formattedDuration: String {
        let s = Int(duration)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

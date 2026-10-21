import Foundation

/// Pauses found while someone was speaking.
struct PauseStats: Equatable {
    var count = 0
    var totalSeconds = 0.0
    var longestSeconds = 0.0

    var meanSeconds: Double { count > 0 ? totalSeconds / Double(count) : 0 }
}

/// Finds pauses from the microphone's loudness, one audio buffer at a time.
///
/// A *pause* is a stretch of at least `minPause` seconds of quiet that sits between
/// two stretches of speech. Quiet before the first word and after the last word is
/// not counted. The "quiet" level is learned from the room itself (its noise floor),
/// so a noisy kitchen and a silent bedroom are both handled, within limits. The first
/// 0.4 s is used to measure that noise, so it is not scored.
///
/// This works from loudness only, so it is an approximation of the pauses a speech
/// scientist would measure.
struct PauseDetector {
    static let minPause = 0.5           // seconds of quiet that count as a pause
    static let speechMargin = 10.0      // dB above the room noise that counts as speech
    static let speechOnset = 0.1        // seconds of sound needed to count as speech resuming
    static let calibration = 0.4        // seconds at the start used to measure the room's noise
    static let maxStartingFloor = -45.0 // dBFS: if the first moments are loud, assume it's speech, not noise
    static let floorRise = 1.0          // dB per second the noise floor may creep up

    private(set) var stats = PauseStats()
    private var floor = PauseDetector.maxStartingFloor
    private var calibrationLeft = PauseDetector.calibration
    private var calibrationMin = Double.infinity
    private var speechStarted = false
    private var quietRun = 0.0          // quiet so far since the last word
    private var loudRun = 0.0           // sound so far since the quiet ended

    /// - Parameters:
    ///   - levelDB: loudness of the buffer in dBFS (0 = full scale, quieter is more negative).
    ///   - duration: length of the buffer in seconds.
    mutating func add(levelDB: Double, duration: Double) {
        guard duration > 0 else { return }

        // Listen to the room for a moment first; the quietest buffer is its noise floor.
        if calibrationLeft > 0 {
            calibrationMin = min(calibrationMin, levelDB)
            calibrationLeft -= duration
            if calibrationLeft <= 0 { floor = min(calibrationMin, Self.maxStartingFloor) }
            return
        }

        let loud = levelDB > floor + Self.speechMargin
        if !loud {
            // Learn the room: follow quiet moments down at once, drift up slowly.
            floor = levelDB < floor ? levelDB : min(levelDB, floor + Self.floorRise * duration)
        }

        if loud {
            loudRun += duration
            if loudRun >= Self.speechOnset {
                // Speech is back (or has started). Close any pause that was open.
                if speechStarted, quietRun >= Self.minPause {
                    stats.count += 1
                    stats.totalSeconds += quietRun
                    stats.longestSeconds = max(stats.longestSeconds, quietRun)
                }
                speechStarted = true
                quietRun = 0
            } else if speechStarted {
                quietRun += duration        // a click or cough inside a pause doesn't end it
            }
        } else {
            loudRun = 0
            if speechStarted { quietRun += duration }
        }
    }
}

import Foundation
@testable import WordPrint

/// Builds `count` distinct letters-only words ("aa", "ab", …) — digits would be
/// stripped by the tokenizer, so we can't use "w1", "w2".
func distinctWords(_ count: Int, offset: Int = 0) -> [String] {
    let letters = Array("abcdefghijklmnopqrstuvwxyz")
    return (0..<count).map { i in
        let n = i + offset
        return String(letters[(n / 26) % 26]) + String(letters[n % 26])
    }
}

let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

func day(_ offset: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: offset, to: referenceDate)!
}

/// A "typical" voice check-in. `i` adds small variation so the baseline has a
/// non-zero spread: different length, filler count and recording time.
func typicalSession(_ i: Int, on date: Date? = nil) -> Session {
    var words = distinctWords(20 + i, offset: i * 3)
    for _ in 0..<(i % 3) { words.insert("um", at: 2) }
    return Session(date: date ?? day(i),
                   duration: TimeInterval(30 + i * 4),
                   transcript: words.joined(separator: " ") + ".")
}

/// A check-in that differs from `typicalSession` on several features at once:
/// more fillers, far less word variety, much slower pace.
func shiftedSession(on date: Date) -> Session {
    let text = "um um um um um like like like like like the the the the the the the the the the."
    return Session(date: date, duration: 120, transcript: text)
}

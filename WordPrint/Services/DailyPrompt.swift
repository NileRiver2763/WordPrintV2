import Foundation

/// The question Neilbot asks today. Picture prompts use one of the scene pictures;
/// asking everyone the same kind of question makes day-to-day speech comparable.
struct DailyPrompt: Identifiable, Equatable {
    let id: String
    let question: String
    /// `Picture.id` of the picture to describe, if this is a picture prompt.
    let pictureID: String?

    var picture: Picture? { pictureID.flatMap(PictureCatalog.picture(id:)) }

    static let all: [DailyPrompt] = [
        DailyPrompt(id: "p-kitchen",  question: "Please describe everything you see in this picture.", pictureID: "kitchen"),
        DailyPrompt(id: "p-tea",      question: "Tell me, step by step, how to make a cup of tea.", pictureID: nil),
        DailyPrompt(id: "p-park",     question: "Tell me what is happening in this picture.", pictureID: "park-bench"),
        DailyPrompt(id: "p-garden",   question: "Please describe everything you see in this picture.", pictureID: "garden"),
        DailyPrompt(id: "p-home",     question: "Describe the home where you grew up.", pictureID: nil),
        DailyPrompt(id: "p-living",   question: "Tell me what is happening in this picture.", pictureID: "living-room"),
        DailyPrompt(id: "p-market",   question: "Please describe everything you see in this picture.", pictureID: "market"),
        DailyPrompt(id: "p-lake",     question: "Tell me what is happening in this picture.", pictureID: "lakeside"),
        DailyPrompt(id: "p-dinner",   question: "Please describe everything you see in this picture.", pictureID: "family-dinner"),
        DailyPrompt(id: "p-bus",      question: "Tell me what is happening in this picture.", pictureID: "bus-stop"),
        DailyPrompt(id: "p-porch",    question: "Please describe everything you see in this picture.", pictureID: "porch"),
        DailyPrompt(id: "p-bakery",   question: "Tell me what is happening in this picture.", pictureID: "bakery"),
    ]

    /// Each check-in gets the next question in the list, so the picture changes every time
    /// and each question comes round again at a regular interval.
    static func forCheckIn(number: Int) -> DailyPrompt {
        all[((number % all.count) + all.count) % all.count]
    }

    static func prompt(id: String) -> DailyPrompt? { all.first { $0.id == id } }
}

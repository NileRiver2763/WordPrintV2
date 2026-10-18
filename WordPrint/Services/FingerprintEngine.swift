import Foundation
import NaturalLanguage

/// Splits text into words, keeping apostrophes inside words so "don't" stays one
/// token instead of becoming "don" and "t".
private func tokenize(_ text: String) -> [String] {
    let keep = CharacterSet.letters.union(CharacterSet(charactersIn: "'’"))
    return text
        .components(separatedBy: keep.inverted)
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'’")) }
        .filter { !$0.isEmpty }
}

// ── Word sets ─────────────────────────────────

private let vaguePronouns: Set<String> = [
    "it", "this", "that", "these", "those",
    "something", "anything", "everything", "nothing",
    "one", "ones", "there", "here"
]

private let genericNouns: Set<String> = [
    "thing", "things", "stuff", "place", "places", "way", "ways",
    "person", "people", "item", "items", "part", "parts",
    "kind", "kinds", "type", "types", "sort", "sorts",
    "lot", "lots", "bit", "bits", "matter", "point"
]

private let fillerWords: Set<String> = [
    "um", "uh", "like", "hmm", "hm", "er", "ah"
]




struct Fingerprint {
    /// Unique word types / total tokens.
    /// Python ref: lexical.ttr()
    /// Healthy ≈ 0.81, Impaired ≈ 0.41 (paper, Table 3)
    var typeTokenRatio: Double

    /// Mean Segmental TTR — average TTR over non-overlapping 50-token windows.
    /// More stable than raw TTR on longer transcripts.
    /// Python ref: lexical.msttr()
    var movingAverageTTR: Double

    /// Vague Language Index composite (0–1).
    /// 0.4 × imprecisePronounRatio + 0.35 × nonSpecificNounRatio + 0.25 × hesitationDensity
    /// Python ref: semantic.compute() → vli_composite
    var vagueLanguageIndex: Double

    /// Filler words (um, uh, like, er, ah, hmm) per 100 tokens.
    /// Python ref: semantic.compute() → filler_rate_per_100
    var fillerRate: Double

    /// Words spoken per minute. Requires durationSeconds > 0.
    /// Python ref: readability.compute() → words_per_minute
    var wordsPerMinute: Double

    /// Average number of words per sentence.
    /// Python ref: readability.compute() → avg_sentence_length
    var meanSentenceLength: Double

    /// Total pronouns / total nouns.
    /// High ratio is a marker of anomia (substituting pronouns for forgotten nouns).
    /// Python ref: syntactic.compute() → pronoun_to_noun_ratio
    var pronounNounRatio: Double
}

extension Fingerprint {
    /// Analyze a speech transcript and return its linguistic fingerprint.
    ///
    /// - Parameters:
    ///   - transcript:      Raw transcript string from SpeechRecognizer.
    ///   - durationSeconds: Recording length in seconds (for wordsPerMinute).
    /// - Returns: A fully populated Fingerprint.
    static func analyze(transcript: String, durationSeconds: Double) -> Fingerprint {
        // TODO: Lowercase the transcript and split it into word tokens.
        //       Hint: use .lowercased() then split on non-alpha characters.
        //       You'll use this [String] array for TTR, MSTTR, fillerRate, wordsPerMinute.
        let lower = transcript.lowercased()
        let tokens = tokenize(lower)
        
        let n = tokens.count
        
        guard n > 0 else {
            return Fingerprint(
                typeTokenRatio:     0,
                movingAverageTTR:   0,
                vagueLanguageIndex: 0,
                fillerRate:         0,
                wordsPerMinute:     0,
                meanSentenceLength: 0,
                pronounNounRatio:   0
            )
        }
        // TODO: Compute typeTokenRatio.
        //       Unique types = Set(tokens).count  /  tokens.count
        //       Guard against empty tokens (return 0.0).
        let uniqueTypes = Set(tokens).count
        let ttr = Double(uniqueTypes) / Double(n)
        // TODO: Compute movingAverageTTR (MSTTR, window = 50 tokens).
        //       Slice tokens into non-overlapping 50-token chunks (stride or manual loop).
        //       Discard the last partial window if len < 50.
        //       Average the TTR of each chunk. Fall back to typeTokenRatio if < 1 full window.
        let windowSize = 50
        var windowTTRs: [Double] = []
        var wi = 0
        while wi + windowSize <= n {
            let window = tokens[wi ..< wi + windowSize]
            windowTTRs.append(Double(Set(window).count) / Double(windowSize))
            wi += windowSize
        }
        let msttr = windowTTRs.isEmpty
        ? ttr
        : windowTTRs.reduce(0, +) / Double(windowTTRs.count)
        // TODO: Compute fillerRate.
        //       Define a Set<String> of fillers: {"um","uh","like","er","ah","hmm","hm"}.
        //       Count how many tokens are in that set, then scale to per-100-tokens.
        let fillerCount   = tokens.filter { fillerWords.contains($0) }.count
        let fillerFraction = Double(fillerCount) / Double(n)
        let fillerPer100   = fillerFraction * 100.0
        // TODO: Compute vagueLanguageIndex using NLTagger(.lexicalClass).
        //       You need three sub-scores:
        //         IPR — vague pronouns / all pronouns
        //         NNR — generic nouns / all nouns
        //         HMD — filler tokens / all tokens (already computed above as fraction)
        //       VLI = 0.4×IPR + 0.35×NNR + 0.25×HMD
        //       Define your vague-pronoun and generic-noun sets as Set<String>.
        //       Use NLTagger to walk each word and bucket it by .lexicalClass tag.
        // TODO: Compute pronounNounRatio using the same NLTagger pass.
        //       Accumulate pronoun count and noun count, then divide.
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = transcript
        let taggerOptions: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        var pronounCount      = 0
        var vaguePronouncCount = 0
        var nounCount         = 0
        var genericNounCount  = 0
        
        tagger.enumerateTags(
            in: transcript.startIndex ..< transcript.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: taggerOptions
        ) { tag, tokenRange in
            guard let tag else { return true }
            let word = String(transcript[tokenRange]).lowercased()
            switch tag {
            case .pronoun:
                pronounCount += 1
                if vaguePronouns.contains(word) { vaguePronouncCount += 1 }
            case .noun:
                nounCount += 1
                if genericNouns.contains(word) { genericNounCount += 1 }
            default:
                break
            }
            return true   // keep enumerating
        }
        let ipr = pronounCount > 0 ? Double(vaguePronouncCount) / Double(pronounCount) : 0.0
        let nnr = nounCount    > 0 ? Double(genericNounCount)   / Double(nounCount)    : 0.0
        let vli = 0.4 * ipr + 0.35 * nnr + 0.25 * fillerFraction
        let pnr = nounCount > 0 ? Double(pronounCount) / Double(nounCount) : 0.0
        // TODO: Compute meanSentenceLength.
        //       Split transcript into sentences. NLTokenizer with .sentence unit works well,
        //       or a simple split on ".","!","?" then filter empty strings.
        //       meanSentenceLength = tokens.count / sentenceCount
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = transcript
        var sentenceCount = 0
        sentenceTokenizer.enumerateTokens(
            in: transcript.startIndex ..< transcript.endIndex
        ) { _, _ in
            sentenceCount += 1
            return true
        }
        let msl = sentenceCount > 0 ? Double(n) / Double(sentenceCount) : Double(n)
        // TODO: Compute wordsPerMinute.
        //       Guard durationSeconds > 0, else return 0.0.
        //       wpm = Double(tokens.count) / (durationSeconds / 60.0)
        let wpm = durationSeconds > 0 ? Double(n) / (durationSeconds / 60.0) : 0.0
        // TODO: Return Fingerprint(
        //           typeTokenRatio:    ...,
        //           movingAverageTTR:  ...,
        //           vagueLanguageIndex: ...,
        //           fillerRate:        ...,
        //           wordsPerMinute:    ...,
        //           meanSentenceLength: ...,
        //           pronounNounRatio:  ...
        //       ) 
        return Fingerprint(
            typeTokenRatio:     (ttr   * 10000).rounded() / 10000,
            movingAverageTTR:   (msttr * 10000).rounded() / 10000,
            vagueLanguageIndex: (vli   * 10000).rounded() / 10000,
            fillerRate:         (fillerPer100 * 100).rounded() / 100,
            wordsPerMinute:     (wpm   * 10).rounded()    / 10,
            meanSentenceLength: (msl   * 100).rounded()   / 100,
            pronounNounRatio:   (pnr   * 10000).rounded() / 10000
        )
    }
}

// ── Baseline & drift ──────────────────────────

/// The seven measurements in a Fingerprint, in a form we can loop over.
enum FingerprintFeature: String, CaseIterable, Identifiable {
    case typeTokenRatio, movingAverageTTR, vagueLanguageIndex, fillerRate
    case wordsPerMinute, meanSentenceLength, pronounNounRatio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typeTokenRatio:     return "Word Variety"
        case .movingAverageTTR:   return "Steady Word Variety"
        case .vagueLanguageIndex: return "Vague Language"
        case .fillerRate:         return "Filler Words"
        case .wordsPerMinute:     return "Speaking Pace"
        case .meanSentenceLength: return "Sentence Length"
        case .pronounNounRatio:   return "Pronouns vs Nouns"
        }
    }

    var unit: String {
        switch self {
        case .fillerRate:         return "per 100 words"
        case .wordsPerMinute:     return "words/min"
        case .meanSentenceLength: return "words"
        default:                  return ""
        }
    }

    func value(in f: Fingerprint) -> Double {
        switch self {
        case .typeTokenRatio:     return f.typeTokenRatio
        case .movingAverageTTR:   return f.movingAverageTTR
        case .vagueLanguageIndex: return f.vagueLanguageIndex
        case .fillerRate:         return f.fillerRate
        case .wordsPerMinute:     return f.wordsPerMinute
        case .meanSentenceLength: return f.meanSentenceLength
        case .pronounNounRatio:   return f.pronounNounRatio
        }
    }
}

struct FeatureBaseline {
    let mean: Double
    let sd: Double       // sample standard deviation (n − 1)
}

/// One check-in's fingerprint, with how far each feature sits from baseline.
struct FingerprintPoint: Identifiable {
    let id = UUID()
    let date: Date
    let fingerprint: Fingerprint
    /// z-score per feature (nil if that feature has no usable baseline spread).
    var zScores: [FingerprintFeature: Double] = [:]
    /// True if this check-in was part of the baseline window.
    var inBaseline: Bool = false
}

struct DriftAnalysis {
    static let minCheckIns      = 3      // baseline appears after this many
    static let minWords         = 15     // shorter transcripts are too noisy to score
    static let zThreshold       = 1.5
    static let featuresNeeded   = 3

    var points: [FingerprintPoint] = []
    var baseline: [FingerprintFeature: FeatureBaseline] = [:]
    var baselineSize = 0
    /// Features that moved the same way, beyond the threshold, in the latest two check-ins.
    var shifted: [(feature: FingerprintFeature, higher: Bool)] = []

    var hasBaseline: Bool { !baseline.isEmpty }
    var isFlagged: Bool { shifted.count >= Self.featuresNeeded }

    /// - Parameter sessions: voice check-ins in any order.
    init(sessions: [Session]) {
        let usable = sessions
            .sorted { $0.date < $1.date }
            .filter { Fingerprint.wordCount($0.transcript) >= Self.minWords }

        points = usable.map {
            FingerprintPoint(date: $0.date,
                             fingerprint: Fingerprint.analyze(transcript: $0.transcript,
                                                              durationSeconds: $0.duration))
        }
        guard points.count >= Self.minCheckIns else { return }

        // Baseline = your earliest check-ins. It is frozen on purpose: if it kept
        // updating, a slow drift would drag the baseline along with it and never
        // look unusual. With 3–4 check-ins we use the first 3; from 5 on, the first 5.
        baselineSize = points.count < 5 ? 3 : 5
        let window = points.prefix(baselineSize)

        for feature in FingerprintFeature.allCases {
            let values = window.map { feature.value(in: $0.fingerprint) }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
            let sd = variance.squareRoot()
            // A flat baseline (sd ≈ 0) would turn tiny wobbles into huge z-scores.
            if sd > 1e-9 { baseline[feature] = FeatureBaseline(mean: mean, sd: sd) }
        }

        for i in points.indices {
            points[i].inBaseline = i < baselineSize
            for (feature, b) in baseline {
                points[i].zScores[feature] = (feature.value(in: points[i].fingerprint) - b.mean) / b.sd
            }
        }

        // Compare only check-ins after the baseline window; need the last two.
        guard points.count >= baselineSize + 2 else { return }
        let last = points[points.count - 1], prev = points[points.count - 2]
        for feature in FingerprintFeature.allCases {
            guard let a = prev.zScores[feature], let b = last.zScores[feature] else { continue }
            let t = Self.zThreshold
            if (a > t && b > t) || (a < -t && b < -t) {
                shifted.append((feature, b > 0))
            }
        }
    }
}

extension Fingerprint {
    static func wordCount(_ text: String) -> Int {
        tokenize(text.lowercased()).count
    }
}

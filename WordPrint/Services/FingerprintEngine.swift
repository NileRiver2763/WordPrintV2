import Foundation
import NaturalLanguage

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
        let tokens = lower
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        
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

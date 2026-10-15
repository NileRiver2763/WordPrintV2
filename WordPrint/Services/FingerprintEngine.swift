import Foundation
import NaturalLanguage

// Maps to the Python engine at ~/print/fingerprint/
// Paper: "Linguistic Fingerprints: AI for Proactive Detection of Cognitive Deficits"

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

        // TODO: Compute typeTokenRatio.
        //       Unique types = Set(tokens).count  /  tokens.count
        //       Guard against empty tokens (return 0.0).

        // TODO: Compute movingAverageTTR (MSTTR, window = 50 tokens).
        //       Slice tokens into non-overlapping 50-token chunks (stride or manual loop).
        //       Discard the last partial window if len < 50.
        //       Average the TTR of each chunk. Fall back to typeTokenRatio if < 1 full window.

        // TODO: Compute fillerRate.
        //       Define a Set<String> of fillers: {"um","uh","like","er","ah","hmm","hm"}.
        //       Count how many tokens are in that set, then scale to per-100-tokens.

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

        // TODO: Compute meanSentenceLength.
        //       Split transcript into sentences. NLTokenizer with .sentence unit works well,
        //       or a simple split on ".","!","?" then filter empty strings.
        //       meanSentenceLength = tokens.count / sentenceCount

        // TODO: Compute wordsPerMinute.
        //       Guard durationSeconds > 0, else return 0.0.
        //       wpm = Double(tokens.count) / (durationSeconds / 60.0)

        // TODO: Return Fingerprint(
        //           typeTokenRatio:    ...,
        //           movingAverageTTR:  ...,
        //           vagueLanguageIndex: ...,
        //           fillerRate:        ...,
        //           wordsPerMinute:    ...,
        //           meanSentenceLength: ...,
        //           pronounNounRatio:  ...
        //       )
        fatalError("Not yet implemented — follow the TODO steps above")
    }
}

//
//  LanguageRecognitionService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import NaturalLanguage
import UIKit

/// A service that evaluates the likelihood that a given string belongs to a
/// specific language.
///
/// `LanguageRecognitionService` combines the Natural Language framework with
/// spell-checking heuristics to produce a confidence score for language
/// identification. The score ranges from `0` (no confidence) to `1`
/// (highest confidence).
///
/// Access the shared service instance using the ``shared`` property:
///
/// ```swift
/// let confidence = await LanguageRecognitionService.shared.matchConfidence(
///     for: "Bonjour le monde",
///     inLanguage: "fr"
/// )
/// ```
///
/// Results are cached automatically; repeated queries for the same string and
/// language code return without recomputation.
///
/// - Important: `LanguageRecognitionService` is an actor. Access its
///   methods with an `await` expression.
public actor LanguageRecognitionService {
    // MARK: - Types

    private struct CacheKey: Hashable {
        let string: String
        let languageCode: String
    }

    // MARK: - Properties

    /// The shared language recognition service instance.
    public static let shared = LanguageRecognitionService()

    private var cachedResults = [CacheKey: Float]()

    // MARK: - Init

    private init() {}

    // MARK: - Methods

    /// Returns a confidence score indicating how likely the given string is
    /// written in the specified language.
    ///
    /// The confidence score is a composite of three weighted signals:
    /// - **Dominant language detection** (weight: 0.4) – Whether the language
    ///   recognizer identifies the string's dominant language as matching the
    ///   given language code.
    /// - **Language hypothesis** (weight: 0.4) – Whether the top language
    ///   hypothesis matches the given language code with at least 45%
    ///   probability.
    /// - **Spell-check validation** (weight: 0.2) – Whether the majority of
    ///   words in the string pass spell-checking for the given language.
    ///
    /// ```swift
    /// let confidence = await LanguageRecognitionService.shared.matchConfidence(
    ///     for: "Guten Morgen",
    ///     inLanguage: "de"
    /// )
    /// // A value greater than 0.8 suggests high likelihood of German text.
    /// ```
    ///
    /// - Parameters:
    ///   - string: The text to evaluate.
    ///   - languageCode: An ISO 639-1 language code (for example, `"en"`,
    ///     `"fr"`, or `"ja"`).
    ///
    /// - Returns: A value between `0` and `1`, where higher values indicate
    ///   greater confidence that the string is written in the specified language.
    ///
    /// - Note: Results are cached for the lifetime of the service instance.
    ///   Identical queries return the cached value without recomputation.
    public func matchConfidence(
        for string: String,
        inLanguage languageCode: String
    ) async -> Float {
        let cacheKey = CacheKey(
            string: string,
            languageCode: languageCode
        )

        if let cachedValue = cachedResults[cacheKey] {
            return cachedValue
        }

        func sanitized(_ string: String) -> String { string.lowercasedTrimmingWhitespaceAndNewlines }

        let languageRecognizer = NLLanguageRecognizer()
        var confidenceValue: Float = 0
        languageRecognizer.processString(string)

        if let dominantLanguageCode = languageRecognizer.dominantLanguage?.rawValue,
           sanitized(dominantLanguageCode).hasPrefix(sanitized(languageCode)) {
            confidenceValue += 0.4
        }

        if let dominantHypothesis = languageRecognizer.languageHypotheses(withMaximum: 1).first,
           sanitized(dominantHypothesis.key.rawValue).hasPrefix(sanitized(languageCode)),
           dominantHypothesis.value >= 0.45 {
            confidenceValue += 0.4
        }

        if await isValidSentence(
            string,
            languageCode: languageCode
        ) {
            confidenceValue += 0.2
        }

        cachedResults[cacheKey] = confidenceValue
        return confidenceValue
    }

    @MainActor
    private func isValidSentence(
        _ string: String,
        languageCode: String
    ) -> Bool {
        func isMisspelled(_ word: String) -> Bool {
            UITextChecker().rangeOfMisspelledWord(
                in: word,
                range: .init(location: 0, length: word.utf16.count),
                startingAt: 0,
                wrap: false,
                language: languageCode
            ).location != NSNotFound
        }

        func shouldCheck(_ word: Substring) -> Bool {
            // Skip tiny words, numbers, URLs-ish, and punctuation-heavy tokens.
            guard word.count >= 3,
                  !word.contains(where: \.isNumber),
                  !word.contains("://"),
                  !word.contains(".") else { return false }
            return word.contains(where: \.isLetter)
        }

        var checkedWords = 0
        var misspelledWords = 0
        var validWords = 0

        let splitString = string.split(whereSeparator: \.isWhitespace)
        for token in splitString where shouldCheck(token) {
            checkedWords += 1

            let word = String(token)
            switch isMisspelled(word) {
            case true: misspelledWords += 1
            case false: validWords += 1
            }

            if checkedWords >= splitString.count / 3 {
                if validWords >= misspelledWords + 2 { return true }
                if misspelledWords >= validWords + 2 { return false }
            }

            if checkedWords >= Int(Double(splitString.count) * 3 / 4) { break }
        }

        // If we couldn't check anything meaningful, don't penalize.
        guard checkedWords > 0 else { return true }
        return validWords >= misspelledWords
    }
}

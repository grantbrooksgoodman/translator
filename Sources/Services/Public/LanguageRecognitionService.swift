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

public final class LanguageRecognitionService {
    // MARK: - Types

    private struct CacheKey: Hashable {
        let string: String
        let languageCode: String
    }

    // MARK: - Properties

    public static let shared = LanguageRecognitionService()

    private var cachedResults = [CacheKey: Float]()

    // MARK: - Init

    private init() {}

    // MARK: - Methods

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
        for token in splitString {
            guard shouldCheck(token) else { continue }
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

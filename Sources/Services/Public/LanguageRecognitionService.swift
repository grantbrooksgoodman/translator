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

public struct LanguageRecognitionService {
    // MARK: - Properties

    public static let shared = LanguageRecognitionService()

    private let nlLanguageRecognizer: NLLanguageRecognizer = .init()
    private let uiTextChecker: UITextChecker = .init()

    // MARK: - Init

    private init() {}

    // MARK: - Methods

    @MainActor
    public func matchConfidence(for string: String, inLanguage languageCode: String) -> Float {
        func sanitized(_ string: String) -> String { string.lowercasedTrimmingWhitespaceAndNewlines }

        var confidenceValue: Float = 0
        nlLanguageRecognizer.processString(string)

        if let dominantLanguageCode = nlLanguageRecognizer.dominantLanguage?.rawValue,
           sanitized(dominantLanguageCode).hasPrefix(sanitized(languageCode)) {
            confidenceValue += 0.4
        }

        if let dominantHypothesis = nlLanguageRecognizer.languageHypotheses(withMaximum: 1).first,
           sanitized(dominantHypothesis.key.rawValue).hasPrefix(sanitized(languageCode)),
           dominantHypothesis.value >= 0.45 {
            confidenceValue += 0.4
        }

        if isValidSentence(string, languageCode: languageCode) {
            confidenceValue += 0.2
        }

        return confidenceValue
    }

    private func isValidSentence(_ string: String, languageCode: String) -> Bool {
        func isMisspelled(_ word: String) -> Bool {
            uiTextChecker.rangeOfMisspelledWord(
                in: word,
                range: .init(location: 0, length: word.utf16.count),
                startingAt: 0,
                wrap: false,
                language: languageCode
            ).location != NSNotFound
        }

        let results = string.components(separatedBy: .whitespaces).reduce(into: [Bool]()) { partialResult, word in
            partialResult.append(isMisspelled(word))
        }

        return results.filter { !$0 }.count > results.filter { $0 }.count
    }
}

//
//  Translation.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A completed translation containing the original input, the translated
/// output, and the language pair.
///
/// You receive `Translation` values from the translation methods on
/// ``TranslationService``:
///
/// ```swift
/// let result = await TranslationService.shared.translate(
///     TranslationInput("Hello"),
///     languagePair: LanguagePair(from: "en", to: "es")
/// )
///
/// if case let .success(translation) = result {
///     print(translation.output) // The translated text
/// }
/// ```
///
/// `Translation` conforms to `Codable` and `Hashable`, making it suitable
/// for persistence and use in sets or as dictionary keys.
/// ``LocalTranslationArchiver`` uses these conformances to cache and
/// retrieve translations on disk.
public struct Translation: Codable, Hashable, Sendable {
    // MARK: - Properties

    /// The original input that was translated.
    public let input: TranslationInput

    /// The language pair used to produce this translation.
    public let languagePair: LanguagePair

    /// The translated text.
    public let output: String

    // MARK: - Init

    /// Creates a translation with the given input, output, and language pair.
    ///
    /// - Parameters:
    ///   - input: The original ``TranslationInput`` that was translated.
    ///   - output: The translated text.
    ///   - languagePair: The ``LanguagePair`` describing the source and
    ///     target languages.
    public init(
        input: TranslationInput,
        output: String,
        languagePair: LanguagePair
    ) {
        self.input = input
        self.output = output
        self.languagePair = languagePair
    }
}

extension Translation: Validatable {
    /// A Boolean value that indicates whether this translation is valid.
    ///
    /// A translation is well-formed when all of the following are true:
    /// - The ``input`` is well-formed.
    /// - The ``languagePair`` is well-formed.
    /// - The ``output`` is not blank.
    ///
    /// ``TranslationService`` checks this property before caching a
    /// completed translation. Malformed translations are discarded and
    /// reported as ``TranslationError/malformedTranslationResult``.
    public var isWellFormed: Bool {
        let isInputValid = input.isWellFormed
        let isLanguagePairValid = languagePair.isWellFormed
        let isOutputValid = TranslationInput(output).isWellFormed
        return isInputValid && isLanguagePairValid && isOutputValid
    }
}

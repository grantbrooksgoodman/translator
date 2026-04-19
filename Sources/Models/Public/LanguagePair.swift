//
//  LanguagePair.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A pair of ISO 639-1 language codes representing the source and target
/// languages for a translation.
///
/// Create a language pair by specifying two-character language codes for
/// the source and target languages:
///
/// ```swift
/// let pair = LanguagePair(from: "en", to: "fr")
/// ```
///
/// You can also create a language pair from a hyphenated string
/// representation:
///
/// ```swift
/// let pair = LanguagePair("en-fr")
/// ```
///
/// The ``isWellFormed`` property indicates whether both language codes are
/// valid. A well-formed language pair contains exactly two non-blank
/// characters in each code.
///
/// - Important: Both ``from`` and ``to`` must be exactly two characters long
///   to pass validation. Language codes that do not conform to ISO 639-1
///   (for example, `"eng"` or `"french"`) cause the pair to fail validation.
public struct LanguagePair: Codable, Hashable, Sendable {
    // MARK: - Properties

    /// The ISO 639-1 language code of the source language.
    public let from: String

    /// The ISO 639-1 language code of the target language.
    public let to: String

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether the source and target languages
    /// are identical.
    ///
    /// When a language pair is idempotent, ``TranslationService`` returns the
    /// original input unchanged without performing a network request.
    public var isIdempotent: Bool { from == to }

    /// A hyphenated string representation of the language pair.
    ///
    /// The format is `"from-to"` – for example, `"en-fr"` for English to
    /// French.
    public var string: String { "\(from)-\(to)" }

    // MARK: - Init

    /// Creates a language pair with the given source and target language codes.
    ///
    /// - Parameters:
    ///   - from: The ISO 639-1 code of the source language.
    ///   - to: The ISO 639-1 code of the target language.
    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }

    /// Creates a language pair by parsing a hyphenated string.
    ///
    /// The expected format is `"from-to"` – for example, `"en-fr"`. If the
    /// string contains only one component, the resulting pair uses that
    /// component as both the source and target language, producing an
    /// idempotent pair.
    ///
    /// Returns `nil` if the string is empty.
    ///
    /// - Parameter string: A hyphenated language pair string to parse.
    public init?(_ string: String) {
        let components = string.components(separatedBy: "-")
        guard !components.isEmpty else { return nil }

        let fromValue = components[0].lowercasedTrimmingWhitespaceAndNewlines
        guard components.count > 1 else {
            self.init(from: fromValue, to: fromValue)
            return
        }

        let toValue = components[1 ... components.count - 1].joined().lowercasedTrimmingWhitespaceAndNewlines
        self.init(from: fromValue, to: toValue)
    }
}

extension LanguagePair: Validatable {
    /// A Boolean value that indicates whether this language pair is valid.
    ///
    /// A language pair is well-formed when both ``from`` and ``to`` are
    /// non-blank strings of exactly two characters. Methods on
    /// ``TranslationService`` check this property before attempting a
    /// translation and return ``TranslationError/invalidArguments`` when
    /// it is `false`.
    public var isWellFormed: Bool {
        let isFromValid = !from.isBlank && from.count == 2
        let isToValid = !to.isBlank && to.count == 2
        return isFromValid && isToValid
    }
}

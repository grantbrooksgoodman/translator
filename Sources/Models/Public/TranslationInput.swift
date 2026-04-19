//
//  TranslationInput.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A value that represents the source text for a translation request.
///
/// A `TranslationInput` supports an optional ``alternate`` string that,
/// when provided, takes precedence over the ``original`` during
/// translation.
///
/// Create an input with a single string:
///
/// ```swift
/// let input = TranslationInput("Hello, world!")
/// ```
///
/// To preserve the original text while translating a modified version,
/// provide both an original and an alternate:
///
/// ```swift
/// let input = TranslationInput("Hello, world!", alternate: "Hello world")
/// ```
///
/// The ``value`` property always resolves to the string that
/// ``TranslationService`` uses for translation – the ``alternate`` if one
/// exists, or the ``original`` otherwise.
///
/// - Note: `TranslationInput` conforms to `Codable`, `Hashable`, and
///   `Sendable`, making it safe to persist, compare, and pass across
///   concurrency boundaries.
public struct TranslationInput: Codable, Hashable, Sendable {
    // MARK: - Properties

    /// The original source text provided at initialization.
    public let original: String

    /// An optional replacement string to use in place of ``original``
    /// during translation.
    ///
    /// When this value is non-`nil`, ``value`` returns it instead of
    /// ``original``. Use this when you need to translate a pre-processed
    /// or sanitized variant while retaining the unmodified original.
    public let alternate: String?

    // MARK: - Computed Properties

    /// The string that ``TranslationService`` translates.
    ///
    /// Returns ``alternate`` if one was provided; otherwise returns
    /// ``original``.
    public var value: String { alternate ?? original }

    var withTokenizedDetectorAttributes: TranslationInput {
        typealias Strings = Constants.Strings.Core
        var stringValue = value

        let detectorType: NSTextCheckingResult.CheckingType = [
            .address,
            .link,
            .phoneNumber,
        ]

        guard let dataDetector = try? NSDataDetector(types: detectorType.rawValue) else { return self }

        for taggableString in dataDetector.matches(
            in: stringValue,
            range: .init(location: 0, length: stringValue.utf16.count)
        ).compactMap({ Range($0.range, in: value) }).compactMap({ String(value[$0]) }) {
            stringValue = stringValue.replacingOccurrences(
                of: taggableString,
                with: "\(Strings.processingDelimiter)\(taggableString)\(Strings.processingDelimiter)"
            )
        }

        guard stringValue != value else { return self }
        return .init(stringValue)
    }

    // MARK: - Init

    /// Creates a translation input with an original string and an optional
    /// alternate.
    ///
    /// - Parameters:
    ///   - original: The original source text.
    ///   - alternate: An optional replacement string to translate in place
    ///     of the original. Pass `nil` to translate the original directly.
    public init(_ original: String, alternate: String?) {
        self.original = original
        self.alternate = alternate
    }

    /// Creates a translation input with the given string.
    ///
    /// - Parameter original: The source text to translate.
    public init(_ original: String) {
        self.init(original, alternate: nil)
    }
}

extension TranslationInput: Validatable {
    /// A Boolean value that indicates whether this input is valid for
    /// translation.
    ///
    /// An input is well-formed when its ``value`` is not blank. Methods
    /// on ``TranslationService`` check this property before attempting a
    /// translation and return ``TranslationError/invalidArguments`` when
    /// it is `false`.
    public var isWellFormed: Bool { !value.isBlank }
}

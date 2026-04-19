//
//  TranslationError.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// An error that occurs during a translation operation.
///
/// `TranslationError` conforms to `LocalizedError`, providing a
/// human-readable ``errorDescription`` for each case. You receive these
/// errors as the failure value of the `Result` returned by
/// ``TranslationService`` methods:
///
/// ```swift
/// let result = await TranslationService.shared.translate(
///     TranslationInput("Hello"),
///     languagePair: LanguagePair(from: "en", to: "es")
/// )
///
/// if case let .failure(error) = result {
///     print(error.localizedDescription)
/// }
/// ```
///
/// Some cases include an associated `String` value with additional detail
/// about the failure.
public enum TranslationError: LocalizedError {
    // MARK: - Cases

    /// JavaScript evaluation on the translation platform's web page failed.
    ///
    /// The associated value, when present, contains a description of the
    /// underlying JavaScript error.
    case evaluateJavaScriptFailed(String? = nil)

    /// The service was unable to construct a valid request URL for the
    /// selected platform and language pair.
    ///
    /// This typically indicates that the platform does not support one or
    /// both of the requested language codes.
    case failedToGenerateRequestURL

    /// One or more arguments passed to the translation method are invalid.
    ///
    /// Verify that the ``TranslationInput`` is not blank and that both
    /// language codes in the ``LanguagePair`` are exactly two characters
    /// long.
    case invalidArguments

    /// The translation platform returned a JavaScript error.
    ///
    /// The associated value contains the error message reported by the
    /// platform.
    case javaScriptError(String)

    /// The translated result could not be processed into a valid
    /// ``Translation``.
    ///
    /// This can occur when the platform returns an empty or structurally
    /// unexpected response.
    case malformedTranslationResult

    /// The translation operation exceeded its time limit.
    case timedOut

    /// Navigation to the translation platform's web page failed.
    ///
    /// The associated value contains a description of the navigation error.
    case webViewNavigationFailed(String)

    /// An error that does not fall into any other category.
    ///
    /// The associated value, when present, contains a description of the
    /// error.
    case unknown(String? = nil)

    // MARK: - Properties

    /// A localized, human-readable description of the error.
    public var errorDescription: String? {
        switch self {
        case let .evaluateJavaScriptFailed(errorDescription):
            "Failed to evaluate JavaScript: \(errorDescription ?? "An unknown error occurred.")"

        case .failedToGenerateRequestURL:
            "Failed to generate request URL."

        case .invalidArguments:
            "The arguments are invalid."

        case let .javaScriptError(errorDescription):
            "JavaScript error occurred: \(errorDescription)"

        case .malformedTranslationResult:
            "Malformed translation result."

        case .timedOut:
            "The operation timed out."

        case let .webViewNavigationFailed(errorDescription):
            "Web view navigation failed: \(errorDescription)"

        case let .unknown(errorDescription):
            errorDescription ?? "An unknown error occurred."
        }
    }
}

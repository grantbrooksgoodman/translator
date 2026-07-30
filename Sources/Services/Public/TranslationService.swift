//
//  TranslationService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A service that translates text between languages using multiple translation platforms.
///
/// `TranslationService` is the primary interface for performing translations. It coordinates
/// between multiple translation platforms – Google Translate, DeepL, Lara, and Reverso – and
/// automatically falls back to alternative platforms when a translation fails or returns
/// an unchanged result.
///
/// Access the shared service instance using the ``shared`` property:
///
/// ```swift
/// let service = TranslationService.shared
/// ```
///
/// To translate a single input with automatic platform fallback:
///
/// ```swift
/// let input = TranslationInput("Hello")
/// let languagePair = LanguagePair(from: "en", to: "es")
/// let translation = try await TranslationService.shared.translate(
///    input,
///    languagePair: languagePair
/// )
/// ```
///
/// The service caches completed translations locally. Subsequent requests for the same
/// input and language pair return the cached result without performing a network request.
///
/// - Important: All translation methods are asynchronous. Call them from an asynchronous context.
public struct TranslationService: Sendable {
    // MARK: - Type Aliases

    private typealias Strings = Constants.Strings.Core

    // MARK: - Properties

    /// The shared translation service instance.
    public static let shared = TranslationService()

    // MARK: - Init

    private init() {}

    // MARK: - Prewarm

    /// Warms the underlying network connections to translation service hosts.
    ///
    /// Call this method early in the app lifecycle (e.g. at launch) to establish
    /// DNS resolution and TLS sessions ahead of the first translation request.
    /// This also precompiles the content-blocking rules used by the web view
    /// pipeline, reducing latency on the first call to
    /// ``translate(_:languagePair:)`` without retaining any web views or
    /// accumulating cookies.
    ///
    /// ```swift
    /// TranslationService.shared.prewarm()
    /// ```
    ///
    /// - Parameter platforms: The platforms to prewarm connections for.
    ///   Defaults to ``TranslationPlatform/allCases``.
    @MainActor
    public func prewarm(
        _ platforms: [TranslationPlatform] = TranslationPlatform.allCases
    ) {
        BaseTranslator.prewarm(platforms)

        // Decode and index the local archive ahead of the first lookup.
        if Translator.config.archiverDelegate == nil {
            LocalTranslationArchiver.shared.preload()
        }
    }

    // MARK: - Translate

    /// Translates the given input into the target language, automatically selecting
    /// the best platform and falling back to alternatives as needed.
    ///
    /// The service attempts translation using Google Translate first. If Google returns
    /// an unchanged result or fails, it falls back to DeepL, then to Reverso, and
    /// finally to Lara.
    ///
    /// Concurrent calls for the same input and language pair are coalesced into
    /// a single request; duplicate callers receive the shared result.
    ///
    /// ```swift
    /// do {
    ///     let translation = try await TranslationService.shared.translate(
    ///         TranslationInput("Good morning"),
    ///         languagePair: LanguagePair(from: "en", to: "fr")
    ///     )
    ///     print(translation.output)
    /// } catch {
    ///     print(error.localizedDescription)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - input: A ``TranslationInput`` value containing the text to translate.
    ///   - languagePair: The source and target languages for the translation.
    ///
    /// - Returns: The completed ``Translation``.
    ///
    /// - Throws: ``TranslationError`` if all platforms fail to produce a translation.
    public func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair
    ) async throws -> Translation {
        // Coalesce concurrent requests for the same input and language pair
        // into a single platform request; duplicate callers await the shared
        // result rather than each spawning their own network work.
        try await InFlightTranslationCoordinator.shared.task(
            forKey: "\(input.value.encodedHash)|\(languagePair.string)"
        ) {
            try await translateWithFallback(
                input,
                languagePair: languagePair
            )
        }.value
    }

    /// Translates the given input into the target language using a specific
    /// translation platform.
    ///
    /// Unlike ``translate(_:languagePair:)``, this method targets a single platform
    /// and does not fall back to alternatives on failure.
    ///
    /// The service performs several optimizations before making a network request:
    /// - If the input contains no Unicode letter characters, the original value
    ///   is returned as-is.
    /// - If the source and target languages are the same, the input is returned unchanged.
    /// - If a cached translation exists for the input and language pair, the cached
    ///   result is returned.
    /// - If the input text is already recognized as the target language with high
    ///   confidence, the input is returned unchanged.
    ///
    /// Addresses, links, and phone numbers detected within the input are tokenized
    /// and preserved through translation.
    ///
    /// - Parameters:
    ///   - input: A ``TranslationInput`` value containing the text to translate.
    ///   - languagePair: The source and target languages for the translation.
    ///   - platform: The ``TranslationPlatform`` to use for translation.
    ///
    /// - Returns: The completed ``Translation``.
    ///
    /// - Throws: ``TranslationError`` if the translation cannot be completed.
    ///
    /// - Important: Both the input and language pair must pass validation. If either
    ///   is malformed, the method throws ``TranslationError/invalidArguments``.
    public func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair,
        platform: TranslationPlatform
    ) async throws -> Translation {
        let input = input.withTokenizedDetectorAttributes
        guard input.isWellFormed,
              languagePair.isWellFormed else { throw TranslationError.invalidArguments }

        let translationArchiver = Translator.config.archiverDelegate ?? LocalTranslationArchiver.shared

        if !input.value.containsLetters || languagePair.isIdempotent {
            return .init(
                input: input,
                output: input.value.replacingOccurrences(
                    of: Strings.processingDelimiter,
                    with: ""
                ),
                languagePair: languagePair
            )
        }

        // Consult the archive before running language recognition; cache hits
        // shouldn't pay for dominant-language analysis and spell-checking.
        if let archivedTranslation = translationArchiver.getValue(
            inputValueEncodedHash: input.value.encodedHash,
            languagePair: languagePair
        ) ?? translationArchiver.getValue(
            inputValueEncodedHash: input.value.trimmingTrailingWhitespaceAndNewlines.encodedHash,
            languagePair: languagePair
        ) {
            guard archivedTranslation.isWellFormed else {
                translationArchiver.removeValue(
                    inputValueEncodedHash: archivedTranslation.input.value.encodedHash,
                    languagePair: archivedTranslation.languagePair
                )

                return try await translate(
                    input,
                    languagePair: languagePair,
                    platform: platform
                )
            }

            return .init(
                input: input,
                output: archivedTranslation.output,
                languagePair: languagePair
            )
        }

        if await LanguageRecognitionService.shared.matchConfidence(
            for: input.value,
            inLanguage: languagePair.to
        ) > 0.8 {
            return .init(
                input: input,
                output: input.value.replacingOccurrences(
                    of: Strings.processingDelimiter,
                    with: ""
                ),
                languagePair: languagePair
            )
        }

        let inputTokens = input.value.tokenized(delimiter: Strings.processingDelimiter)
        let translation = try await platform.instance.translate(
            .init(inputTokens.processed.trimmingTrailingWhitespaceAndNewlines),
            languagePair: languagePair
        )

        if !inputTokens.slices.isEmpty,
           !translation.output.contains(Strings.processingToken) {
            throw TranslationError.malformedTranslationResult
        }

        let processedOutput = translation
            .output
            .replacing(token: Strings.processingToken, with: inputTokens.slices)
            .replacingOccurrences(of: Strings.processingToken, with: "")
            .replacingOccurrences(of: Strings.processingDelimiter, with: "")
            .trimmingTrailingWhitespaceAndNewlines
            .capitalized(relativeTo: input.value)

        let processedTranslation: Translation = .init(
            input: input,
            output: processedOutput,
            languagePair: translation.languagePair
        )

        guard processedTranslation.isWellFormed else {
            throw TranslationError.malformedTranslationResult
        }

        translationArchiver.addValue(processedTranslation)
        return processedTranslation
    }

    private func translateWithFallback(
        _ input: TranslationInput,
        languagePair: LanguagePair
    ) async throws -> Translation {
        let fallbackPlatforms: [TranslationPlatform] = [
            .google,
            .deepL,
            .reverso,
        ]

        for platform in fallbackPlatforms {
            if let translation = try? await translate(
                input,
                languagePair: languagePair,
                platform: platform
            ), translation.output.normalized != input.value.normalized {
                return translation
            }
        }

        return try await translate(
            input,
            languagePair: languagePair,
            platform: .lara
        )
    }

    // MARK: - Get Translations

    /// Translates multiple inputs into the target language concurrently.
    ///
    /// Use this method to translate a batch of inputs in a single call. The service
    /// processes up to 10 translations concurrently and returns results in the same
    /// order as the original inputs.
    ///
    /// ```swift
    /// let inputs: [TranslationInput] = [
    ///     .init("Hello"),
    ///     .init("Goodbye"),
    ///     .init("Thank you"),
    /// ]
    ///
    /// let translations = try await TranslationService.shared.getTranslations(
    ///     inputs,
    ///     languagePair: LanguagePair(from: "en", to: "ja")
    /// )
    /// ```
    ///
    /// Each input is translated using ``translate(_:languagePair:)`` with automatic
    /// platform fallback. If any translation in the batch fails, the entire
    /// operation is canceled and the error is thrown.
    ///
    /// - Parameters:
    ///   - inputs: An array of ``TranslationInput`` values to translate. The array
    ///     must not be empty.
    ///   - languagePair: The source and target languages for all translations.
    ///
    /// - Returns: An array of ``Translation`` values corresponding positionally
    ///   to the input array.
    ///
    /// - Throws: ``TranslationError`` if any translation in the batch fails.
    ///
    /// - Important: All inputs and the language pair must pass validation. If any
    ///   argument is malformed, the method throws ``TranslationError/invalidArguments``.
    public func getTranslations(
        _ inputs: [TranslationInput],
        languagePair: LanguagePair
    ) async throws -> [Translation] {
        guard !inputs.isEmpty,
              inputs.allSatisfy(\.isWellFormed),
              languagePair.isWellFormed else { throw TranslationError.invalidArguments }

        // Pre-allocate result slots to preserve order.
        var translations: [Translation?] = Array(
            repeating: nil,
            count: inputs.count
        )

        try await withThrowingTaskGroup(
            of: (Int, Translation).self
        ) { taskGroup in
            var nextIndex = 0

            func enqueueNextTask() {
                guard nextIndex < inputs.count else { return }
                let index = nextIndex
                nextIndex += 1

                taskGroup.addTask {
                    let translation = try await translate(
                        inputs[index],
                        languagePair: languagePair
                    )

                    return (index, translation)
                }
            }

            let maxConcurrentOperations = min(
                10,
                inputs.count
            )

            for _ in 0 ..< maxConcurrentOperations {
                enqueueNextTask()
            }

            // As each task finishes, enqueue another until done.
            for try await (index, translation) in taskGroup {
                translations[index] = translation
                enqueueNextTask()
            }
        }

        guard translations.allSatisfy({ $0 != nil }) else {
            throw TranslationError.unknown(
                "Batch translation results were incomplete."
            )
        }

        return translations.compactMap(\.self)
    }
}

private extension String {
    var normalized: String {
        lowercasedTrimmingWhitespaceAndNewlines
    }
}

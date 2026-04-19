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
/// between multiple translation platforms – Google Translate, DeepL, and Reverso – and
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
/// let result = await TranslationService.shared.translate(
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

    // MARK: - Translate

    /// Translates the given input into the target language, automatically selecting
    /// the best platform and falling back to alternatives as needed.
    ///
    /// The service attempts translation using Google Translate first. If Google returns
    /// an unchanged result or fails, it falls back to DeepL, and then to Reverso.
    ///
    /// ```swift
    /// let result = await TranslationService.shared.translate(
    ///     TranslationInput("Good morning"),
    ///     languagePair: LanguagePair(from: "en", to: "fr")
    /// )
    ///
    /// switch result {
    /// case let .success(translation):
    ///     print(translation.output)
    /// case let .failure(error):
    ///     print(error.localizedDescription)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - input: A ``TranslationInput`` value containing the text to translate.
    ///   - languagePair: The source and target languages for the translation.
    ///
    /// - Returns: A `Result` containing the completed ``Translation`` on success,
    ///   or a ``TranslationError`` on failure.
    public func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Result<Translation, TranslationError> {
        func deepLFailureScenario() async -> Result<Translation, TranslationError> {
            let translateWithReversoResult = await translate(
                input,
                languagePair: languagePair,
                platform: .reverso
            )

            switch translateWithReversoResult {
            case let .success(translation):
                return .success(translation)

            case let .failure(error):
                return .failure(error)
            }
        }

        func googleFailureScenario() async -> Result<Translation, TranslationError> {
            let translateWithDeepLResult = await translate(
                input,
                languagePair: languagePair,
                platform: .deepL
            )

            switch translateWithDeepLResult {
            case let .success(translation):
                guard translation.output.normalized != input.value.normalized else { return await deepLFailureScenario() }
                return .success(translation)

            case .failure:
                return await deepLFailureScenario()
            }
        }

        let translateWithGoogleResult = await translate(
            input,
            languagePair: languagePair,
            platform: .google
        )

        switch translateWithGoogleResult {
        case let .success(translation):
            guard translation.output.normalized != input.value.normalized else { return await googleFailureScenario() }
            return .success(translation)

        case .failure:
            return await googleFailureScenario()
        }
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
    /// - If the input text is already recognized as the target language with high
    ///   confidence, the input is returned unchanged.
    /// - If a cached translation exists for the input and language pair, the cached
    ///   result is returned.
    ///
    /// Addresses, links, and phone numbers detected within the input are tokenized
    /// and preserved through translation.
    ///
    /// - Parameters:
    ///   - input: A ``TranslationInput`` value containing the text to translate.
    ///   - languagePair: The source and target languages for the translation.
    ///   - platform: The ``TranslationPlatform`` to use for translation.
    ///
    /// - Returns: A `Result` containing the completed ``Translation`` on success,
    ///   or a ``TranslationError`` on failure.
    ///
    /// - Important: Both the input and language pair must pass validation. If either
    ///   is malformed, the method returns ``TranslationError/invalidArguments``.
    public func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair,
        platform: TranslationPlatform
    ) async -> Result<Translation, TranslationError> {
        let input = input.withTokenizedDetectorAttributes
        guard input.isWellFormed,
              languagePair.isWellFormed else { return .failure(.invalidArguments) }

        let translationArchiver = Translator.config.archiverDelegate ?? LocalTranslationArchiver.shared

        let hasUnicodeLetters = input.value.containsLetters
        let sameInputOutputLanguage = await LanguageRecognitionService.shared.matchConfidence(for: input.value, inLanguage: languagePair.to) > 0.8

        if !hasUnicodeLetters || languagePair.isIdempotent || sameInputOutputLanguage {
            return .success(.init(
                input: input,
                output: input.value.replacingOccurrences(of: Strings.processingDelimiter, with: ""),
                languagePair: languagePair
            ))
        }

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
                return await translate(input, languagePair: languagePair, platform: platform)
            }

            return .success(.init(
                input: input,
                output: archivedTranslation.output,
                languagePair: languagePair
            ))
        }

        let inputTokens = input.value.tokenized(delimiter: Strings.processingDelimiter)
        let translateResult = await platform.instance.translate(
            .init(inputTokens.processed.trimmingTrailingWhitespaceAndNewlines),
            languagePair: languagePair
        )

        switch translateResult {
        case let .success(translation):
            if !inputTokens.slices.isEmpty,
               !translation.output.contains(Strings.processingToken) {
                return .failure(.malformedTranslationResult)
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

            guard processedTranslation.isWellFormed else { return .failure(.malformedTranslationResult) }
            translationArchiver.addValue(processedTranslation)
            return .success(processedTranslation)

        case let .failure(error):
            return .failure(error)
        }
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
    /// let result = await TranslationService.shared.getTranslations(
    ///     inputs,
    ///     languagePair: LanguagePair(from: "en", to: "ja")
    /// )
    /// ```
    ///
    /// Each input is translated using ``translate(_:languagePair:)`` with automatic
    /// platform fallback. If any translation in the batch fails, the entire
    /// operation is canceled and the error is returned.
    ///
    /// - Parameters:
    ///   - inputs: An array of ``TranslationInput`` values to translate. The array
    ///     must not be empty.
    ///   - languagePair: The source and target languages for all translations.
    ///
    /// - Returns: A `Result` containing an array of ``Translation`` values on success,
    ///   or a ``TranslationError`` on failure. The translations correspond positionally
    ///   to the input array.
    ///
    /// - Important: All inputs and the language pair must pass validation. If any
    ///   argument is malformed, the method returns ``TranslationError/invalidArguments``.
    public func getTranslations(
        _ inputs: [TranslationInput],
        languagePair: LanguagePair
    ) async -> Result<[Translation], TranslationError> {
        guard !inputs.isEmpty,
              inputs.allSatisfy(\.isWellFormed),
              languagePair.isWellFormed else { return .failure(.invalidArguments) }

        // Pre-allocate result slots to preserve order.
        var translations: [Translation?] = Array(
            repeating: nil,
            count: inputs.count
        )

        return await withTaskGroup(
            of: (Int, Result<Translation, TranslationError>).self
        ) { taskGroup in
            var error: TranslationError?
            var nextIndex = 0

            func enqueueNextTask() {
                guard nextIndex < inputs.count else { return }
                let index = nextIndex
                nextIndex += 1

                taskGroup.addTask {
                    let translateResult = await translate(
                        inputs[index],
                        languagePair: languagePair
                    )

                    return (index, translateResult)
                }
            }

            let maxConcurrentOperations = min(
                10,
                inputs.count
            )

            for _ in 0 ..< maxConcurrentOperations { enqueueNextTask() }

            // As each task finishes, enqueue another until done.
            while let (index, result) = await taskGroup.next() {
                switch result {
                case let .success(translation):
                    translations[index] = translation
                    enqueueNextTask()

                case let .failure(_error):
                    error = _error
                    taskGroup.cancelAll()
                }
            }

            if let error { return .failure(error) }
            guard translations.allSatisfy({ $0 != nil }) else {
                return .failure(.unknown(
                    "Batch translation results were incomplete."
                ))
            }

            return .success(translations.compactMap(\.self))
        }
    }
}

private extension String {
    var normalized: String {
        lowercasedTrimmingWhitespaceAndNewlines
    }
}

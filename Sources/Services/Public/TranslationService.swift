//
//  TranslationService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct TranslationService {
    // MARK: - Type Aliases

    private typealias Strings = Constants.Strings.Core

    // MARK: - Properties

    public static let shared = TranslationService()

    // MARK: - Init

    private init() {}

    // MARK: - Translate

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

    public func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair,
        platform: TranslationPlatform
    ) async -> Result<Translation, TranslationError> {
        let input = input.withTokenizedDetectorAttributes
        guard input.isWellFormed,
              languagePair.isWellFormed else { return .failure(.invalidArguments) }

        let translationArchiver = Config.shared.archiverDelegate ?? LocalTranslationArchiver.shared

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

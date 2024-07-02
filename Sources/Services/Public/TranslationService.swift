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

    private func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair,
        platform: TranslationPlatform
    ) async -> Result<Translation, TranslationError> {
        let input = input.withTokenizedDetectorAttributes
        guard input.isWellFormed,
              languagePair.isWellFormed else { return .failure(.invalidArguments) }

        let translationArchiver = Config.shared.archiverDelegate ?? LocalTranslationArchiver.shared

        let hasUnicodeLetters = input.value.rangeOfCharacter(from: .letters) != nil
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
        var translations = [Translation]()

        for input in inputs {
            let translateResult = await translate(input, languagePair: languagePair)

            switch translateResult {
            case let .success(translation):
                translations.append(translation)

            case let .failure(error):
                return .failure(error)
            }
        }

        return .success(translations)
    }
}

private extension String {
    var normalized: String {
        lowercasedTrimmingWhitespaceAndNewlines
    }
}

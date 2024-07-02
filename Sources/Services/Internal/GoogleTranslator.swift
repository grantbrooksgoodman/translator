//
//  GoogleTranslator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

final class GoogleTranslator: BaseTranslator, Translatorable {
    // MARK: - Properties

    var platform: TranslationPlatform = .google

    // MARK: - Init

    init() {
        super.init(platform: platform)
    }

    // MARK: - Evaluate JavaScript

    @MainActor
    override func evaluateJavaScript(useAlternateString: Bool = false) async {
        do {
            guard let translationInput,
                  let translationLanguagePair else { return failForMissingValues() }

            let javaScriptString = useAlternateString ? platform.alternateJavaScriptString : platform.javaScriptString

            guard let translationOutput = try await webView?.evaluateJavaScript(javaScriptString) as? String,
                  !translationOutput.lowercasedTrimmingWhitespaceAndNewlines.isEmpty,
                  !translationOutput.contains("(feminine)") else {
                return await retryOrFail(
                    .evaluateJavaScriptFailed(),
                    useAlternateString: true
                )
            }

            setTranslationResult(
                .success(.init(
                    input: translationInput,
                    output: translationOutput.replacingOccurrences(of: "(masculine)", with: ""),
                    languagePair: translationLanguagePair
                ))
            )
        } catch {
            await retryOrFail(
                .javaScriptError(Translator.descriptor(error)),
                useAlternateString: useAlternateString
            )
        }
    }
}

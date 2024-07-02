//
//  ReversoTranslator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

final class ReversoTranslator: BaseTranslator, Translatorable {
    // MARK: - Properties

    var platform: TranslationPlatform = .reverso

    // MARK: - Init

    init() {
        super.init(platform: platform)
    }

    // MARK: - Evaluate JavaScript

    @MainActor
    override func evaluateJavaScript(useAlternateString: Bool = false) async {
        if await restoreLanguagePairIfNeeded() {
            return await retryOrFail(
                .evaluateJavaScriptFailed(),
                useAlternateString: !useAlternateString
            )
        }

        do {
            guard let translationInput,
                  let translationLanguagePair else { return failForMissingValues() }

            let javaScriptString = useAlternateString ? platform.alternateJavaScriptString : platform.javaScriptString

            guard let translationOutput = try await webView?.evaluateJavaScript(javaScriptString) as? String,
                  !translationOutput.lowercasedTrimmingWhitespaceAndNewlines.isEmpty,
                  translationOutput.lowercasedTrimmingWhitespaceAndNewlines != "!" else {
                return await retryOrFail(
                    .evaluateJavaScriptFailed(),
                    useAlternateString: !useAlternateString
                )
            }

            let inputNewlineCount = translationInput.value.components(separatedBy: "\n").count
            let outputComponents = translationOutput.trimmingBorderedNewlines.components(separatedBy: "\n")
            let outputNewlineCount = outputComponents.count

            guard outputNewlineCount >= inputNewlineCount,
                  let firstOutputComponent = outputComponents.first else {
                return await retryOrFail(
                    .evaluateJavaScriptFailed("Failed to process output string."),
                    useAlternateString: !useAlternateString
                )
            }

            let processedOutput = outputNewlineCount >= inputNewlineCount ? process(
                outputComponents[0 ... (inputNewlineCount - 1 < 0 ? 0 : inputNewlineCount - 1)]
                    .joined(separator: "\n")
                    .trimmingTrailingNewlines
            ) : process(
                firstOutputComponent
                    .trimmingTrailingNewlines
            )

            setTranslationResult(
                .success(.init(
                    input: translationInput,
                    output: processedOutput,
                    languagePair: translationLanguagePair
                ))
            )
        } catch {
            await retryOrFail(
                .javaScriptError(Translator.descriptor(error)),
                useAlternateString: !useAlternateString
            )
        }
    }

    // MARK: - Auxiliary

    private func process(_ string: String) -> String {
        let seeMore = "See more translations"
        guard string.contains(seeMore) else { return string }
        return string.components(separatedBy: seeMore)[0].trimmingBorderedNewlines
    }

    /// - Returns: Boolean value indicating whether or not the language pair needed restoring.
    @MainActor
    private func restoreLanguagePairIfNeeded() async -> Bool {
        return await withCheckedContinuation { continuation in
            restoreLanguagePairIfNeeded { continuation.resume(returning: $0) }
        }
    }

    /// Necessary to avoid async/await here due to crashing bug in evaluating JavaScript with no return values.
    /// https://forums.developer.apple.com/forums/thread/701553
    private func restoreLanguagePairIfNeeded(completion: @escaping (Bool) -> Void) {
        webView?.evaluateJavaScript("document.getElementsByClassName('original-language-pair-link')[0].click();") { _, error in
            guard error == nil else { return completion(false) }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { completion(true) }
        }
    }
}

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

    private static let apiURLString = "https://api.reverso.net/translate/v1/translation"

    // MARK: - Computed Properties

    static var apiWarmupURLString: String {
        apiURLString
    }

    // MARK: - Init

    init() {
        super.init(platform: platform)
    }

    // MARK: - Translate

    override func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair
    ) async throws -> Translation {
        // Fast path: Reverso's JSON API responds in a fraction of the time it
        // takes to load and scrape the full web app. Fall back to the web
        // view pipeline whenever it fails.
        do {
            return try await translateWithAPI(
                input,
                languagePair: languagePair
            )
        } catch {
            Translator.config.loggerDelegate?.log(
                "API fast path failed, falling back to web view: \(Translator.descriptor(error))",
                sender: self,
                fileName: #fileID,
                function: #function,
                line: #line
            )

            return try await super.translate(
                input,
                languagePair: languagePair
            )
        }
    }

    private func translateWithAPI(
        _ input: TranslationInput,
        languagePair: LanguagePair
    ) async throws -> Translation {
        guard let source = platform.identifier(for: languagePair.from),
              let target = platform.identifier(for: languagePair.to),
              let requestURL = URL(string: Self.apiURLString) else {
            throw TranslationError.failedToGenerateRequestURL
        }

        let requestBody: [String: Any] = [
            "format": "text",
            "from": source,
            "to": target,
            "input": input.value,
            "options": [
                "contextResults": false,
                "languageDetection": false,
                "origin": "translation.web",
                "sentenceSplitter": false,
            ],
        ]

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        // Reverso rejects requests without a browser-like user agent.
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode,
              statusCode == 200 else {
            throw TranslationError.unknown(
                "Translation API returned an unexpected response."
            )
        }

        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translations = jsonObject["translation"] as? [String] else {
            throw TranslationError.malformedTranslationResult
        }

        let translationOutput = translations.joined()
        guard !translationOutput.lowercasedTrimmingWhitespaceAndNewlines.isEmpty else {
            throw TranslationError.malformedTranslationResult
        }

        return .init(
            input: input,
            output: translationOutput,
            languagePair: languagePair
        )
    }

    // MARK: - Evaluate JavaScript

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
    private func restoreLanguagePairIfNeeded() async -> Bool {
        await withCheckedContinuation { continuation in
            restoreLanguagePairIfNeeded { continuation.resume(returning: $0) }
        }
    }

    /// Necessary to avoid async/await here due to crashing bug in evaluating JavaScript with no return values.
    /// https://forums.developer.apple.com/forums/thread/701553
    private func restoreLanguagePairIfNeeded(completion: @escaping @Sendable (Bool) -> Void) {
        webView?.evaluateJavaScript("document.getElementsByClassName('original-language-pair-link')[0].click();") { _, error in
            guard error == nil else { return completion(false) }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { completion(true) }
        }
    }
}

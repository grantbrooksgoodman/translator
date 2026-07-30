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

    private static let apiBaseURLString = "https://translate.googleapis.com/translate_a/single"

    // MARK: - Computed Properties

    static var apiWarmupURLString: String {
        "\(apiBaseURLString)?client=gtx&dt=t&sl=en&tl=es&q=a"
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
        // Fast path: Google's lightweight JSON endpoint responds in a fraction
        // of the time it takes to load and scrape the full web app. Fall back
        // to the web view pipeline whenever it fails.
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
        // Percent-encode the query manually; `URLQueryItem` leaves characters
        // like "+" un-encoded, which the endpoint would decode as a space.
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "+&=?")

        guard let source = platform.identifier(for: languagePair.from),
              let target = platform.identifier(for: languagePair.to),
              let encodedText = input.value.addingPercentEncoding(withAllowedCharacters: allowedCharacters),
              var urlComponents = URLComponents(string: Self.apiBaseURLString) else {
            throw TranslationError.failedToGenerateRequestURL
        }

        urlComponents.percentEncodedQuery = "client=gtx&dt=t&sl=\(source)&tl=\(target)&q=\(encodedText)"

        guard let requestURL = urlComponents.url else {
            throw TranslationError.failedToGenerateRequestURL
        }

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 5

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode,
              statusCode == 200 else {
            throw TranslationError.unknown(
                "Translation API returned an unexpected response."
            )
        }

        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [Any],
              let segments = jsonObject.first as? [Any] else {
            throw TranslationError.malformedTranslationResult
        }

        let translationOutput = segments
            .compactMap { ($0 as? [Any])?.first as? String }
            .joined()

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

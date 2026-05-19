//
//  LaraTranslator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
@preconcurrency import WebKit

final class LaraTranslator: BaseTranslator, Translatorable {
    // MARK: - Properties

    var platform: TranslationPlatform = .lara

    // MARK: - Init

    init() {
        super.init(platform: platform)
    }

    // MARK: - Configure Web View

    override func configureWebView() {
        // Inject a script into ALL frames (including cross-origin iframes).
        // When the iframe renders the translation, this script finds it and
        // posts the result to the parent frame via postMessage.
        let iframeScript = """
        (function() {
            if (window === window.top) return;

            var className = 'knownFragmentElementNode';
            var timer = setInterval(function() {
                var el = document.getElementsByClassName(className)[0];
                if (el && el.innerText && el.innerText.trim()) {
                    clearInterval(timer);
                    window.top.postMessage(
                        JSON.stringify({ type: 'laraTranslation', text: el.innerText.trim() }),
                        '*'
                    );
                }
            }, 200);

            setTimeout(function() { clearInterval(timer); }, 10000);
        })();
        """

        webView?
            .configuration
            .userContentController
            .addUserScript(.init(
                source: iframeScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            ))
    }

    // MARK: - Evaluate JavaScript

    override func evaluateJavaScript(useAlternateString: Bool = false) async {
        guard let translationInput,
              let translationLanguagePair else { return failForMissingValues() }

        // Listen in the main frame for the postMessage sent by the iframe script.
        let javaScript = """
        return await new Promise(function(resolve) {
            function handler(event) {
                try {
                    var data = JSON.parse(event.data);
                    if (data.type === 'laraTranslation' && data.text) {
                        window.removeEventListener('message', handler);
                        clearTimeout(timeout);
                        resolve(data.text);
                    }
                } catch(e) {}
            }

            window.addEventListener('message', handler);

            var timeout = setTimeout(function() {
                window.removeEventListener('message', handler);
                resolve('');
            }, 9000);
        });
        """

        do {
            guard let translationOutput = try await webView?.callAsyncJavaScript(
                javaScript,
                contentWorld: .page
            ) as? String,
                !translationOutput.lowercasedTrimmingWhitespaceAndNewlines.isEmpty else {
                return setTranslationResult(.failure(
                    .evaluateJavaScriptFailed()
                ))
            }

            setTranslationResult(
                .success(.init(
                    input: translationInput,
                    output: translationOutput,
                    languagePair: translationLanguagePair
                ))
            )
        } catch {
            setTranslationResult(.failure(
                .javaScriptError(Translator.descriptor(error))
            ))
        }
    }
}

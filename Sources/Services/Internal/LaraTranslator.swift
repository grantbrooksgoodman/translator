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

        // The result observer script (injected at document start) listens for
        // the iframe's postMessage and buffers it on the main frame's window.
        // Reading the buffer – rather than attaching a listener here – means
        // results relayed before navigation finishes are never lost.
        let javaScript = """
        if (window.__translatorResult) { return window.__translatorResult; }

        return await new Promise(function(resolve) {
            var elapsedMilliseconds = 0;
            var timer = setInterval(function() {
                if (window.__translatorResult) {
                    clearInterval(timer);
                    resolve(window.__translatorResult);
                } else if ((elapsedMilliseconds += 100) >= 9000) {
                    clearInterval(timer);
                    resolve('');
                }
            }, 100);
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

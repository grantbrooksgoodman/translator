//
//  TranslationPlatform.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The translation platform to use when performing a translation.
///
/// `TranslationPlatform` identifies the third-party web translation service
/// that ``TranslationService`` communicates with. Each case maps to a
/// specific provider:
///
/// | Case | Provider |
/// | --- | --- |
/// | ``deepL`` | DeepL Translator |
/// | ``google`` | Google Translate |
/// | ``lara`` | Lara Translate |
/// | ``reverso`` | Reverso Translation |
///
/// When you call ``TranslationService/translate(_:languagePair:)``, the
/// service automatically selects and falls back between platforms. To target
/// a specific platform, use
/// ``TranslationService/translate(_:languagePair:platform:)`` instead:
///
/// ```swift
/// let translation = try await TranslationService.shared.translate(
///     TranslationInput("Hello"),
///     languagePair: LanguagePair(from: "en", to: "de"),
///     platform: .deepL
/// )
/// ```
///
/// - Note: Not every platform supports every language. If a platform does
///   not support the requested language pair, the translation fails with
///   ``TranslationError/failedToGenerateRequestURL``.
public enum TranslationPlatform: Codable, CaseIterable, Equatable, Sendable {
    // MARK: - Type Aliases

    private typealias Strings = Constants.Strings.TranslationPlatform

    // MARK: - Cases

    /// DeepL Translator.
    case deepL

    /// Google Translate.
    case google

    /// Lara Translate.
    case lara

    /// Reverso Translation.
    case reverso

    // MARK: - Properties

    var alternateJavaScriptString: String {
        switch self {
        case .deepL: Strings.deepLAlternateJavaScriptString
        case .google: Strings.googleAlternateJavaScriptString
        case .lara: Strings.laraJavaScriptString
        case .reverso: Strings.reversoAlternateJavaScriptString
        }
    }

    @MainActor
    var instance: any Translatorable {
        switch self {
        case .deepL: DeepLTranslator()
        case .google: GoogleTranslator()
        case .lara: LaraTranslator()
        case .reverso: ReversoTranslator()
        }
    }

    var javaScriptString: String {
        switch self {
        case .deepL: Strings.deepLJavaScriptString
        case .google: Strings.googleJavaScriptString
        case .lara: Strings.laraJavaScriptString
        case .reverso: Strings.reversoJavaScriptString
        }
    }

    var prewarmURL: URL? {
        let urlString = switch self {
        case .deepL: "https://www.deepl.com/en/translator"
        case .google: "https://translate.google.com/?hl=en"
        case .lara: "https://laratranslate.com/translate"
        case .reverso: "https://www.reverso.net/text-translation"
        }

        return .init(string: urlString)
    }

    /// A script injected into the main frame at document start which notifies
    /// the native side the moment the translation result appears in the DOM,
    /// rather than waiting for the page to finish loading entirely.
    var resultObserverScript: String? {
        typealias Strings = Constants.Strings.Core

        // Lara renders its result inside a cross-origin iframe which relays it
        // to the main frame via postMessage (see `LaraTranslator`). Buffer the
        // relayed result and notify the native side as soon as it arrives.
        guard self != .lara else {
            return """
            (function() {
              window.addEventListener('message', function(event) {
                try {
                  var data = JSON.parse(event.data);
                  if (data.type === 'laraTranslation' && data.text) {
                    window.__translatorResult = data.text;
                    try { window.webkit.messageHandlers.\(Strings.resultObserverMessageHandlerName).postMessage(''); } catch (e) {}
                  }
                } catch (e) {}
              });
            })();
            """
        }

        let readyCheck = switch self {
        case .deepL: """
            var results = document.querySelectorAll('[aria-labelledby="translation-results-heading"]');
            var element = results[results.length - 1];
            if (element && element.innerText && element.innerText.trim()) { return true; }
            results = document.querySelectorAll('[aria-labelledby="translation-target-heading"]');
            element = results[results.length - 1];
            return !!(element && element.innerText && element.innerText.trim());
            """

        case .google: """
            var element = document.getElementsByClassName('lRu31')[0];
            return !!(element && element.innerText && element.innerText.trim());
            """

        case .lara: ""

        case .reverso: """
            var element = document.getElementsByClassName('textarea translation-box__translated-text translation-box__translated-text_favorite')[0] ||
                document.getElementsByClassName('translation-input__main translation-input__result')[0];
            return !!(element && element.innerText && element.innerText.trim() && element.innerText.trim() !== '!');
            """
        }

        return """
        (function() {
          function isReady() {
            try {
              \(readyCheck)
            } catch (e) { return false; }
          }
          function notify() {
            try { window.webkit.messageHandlers.\(Strings.resultObserverMessageHandlerName).postMessage(''); } catch (e) {}
          }
          function observe() {
            if (isReady()) { return notify(); }
            var observer = new MutationObserver(function() {
              if (isReady()) {
                observer.disconnect();
                notify();
              }
            });
            observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
            setTimeout(function() { observer.disconnect(); }, 15000);
          }
          if (document.documentElement) { observe(); }
          else { document.addEventListener('DOMContentLoaded', observe); }
        })();
        """
    }

    // MARK: - Methods

    func identifier(for languageCode: String) -> String? {
        let languageCode = languageCode.lowercasedTrimmingWhitespaceAndNewlines

        switch self {
        case .deepL:
            let supportedLanguageCodes = [
                "bg", "cs",
                "da", "de",
                "el", "en",
                "es", "et",
                "fi", "fr",
                "hu", "id",
                "it", "ja",
                "lt", "lv",
                "nl", "pl",
                "pt", "ro",
                "ru", "sk",
                "sl", "sv",
                "tr", "zh",
            ]

            guard supportedLanguageCodes.contains(languageCode) else { return nil }
            return languageCode

        case .google:
            return languageCode == "he" ? "iw" : languageCode == "zh" ? "zh-CN" : languageCode

        case .lara:
            return languageCode

        case .reverso:
            let languageCodeMap = [
                "ar": "ara",
                "cz": "cze",
                "da": "dan",
                "de": "ger",
                "el": "gre",
                "en": "eng",
                "es": "spa",
                "fa": "per",
                "fr": "fra",
                "he": "heb",
                "hi": "hin",
                "hu": "hun",
                "it": "ita",
                "ja": "jpn",
                "ko": "kor",
                "nl": "dut",
                "pl": "pol",
                "pt": "por",
                "ro": "rum",
                "ru": "rus",
                "sk": "slo",
                "sv": "swe",
                "th": "tha",
                "tr": "tur",
                "uk": "ukr",
                "zh": "chi",
            ]

            return languageCodeMap[languageCode]
        }
    }

    func requestURL(
        _ text: String,
        languagePair: LanguagePair
    ) -> URL? {
        guard let source = identifier(for: languagePair.from),
              let target = identifier(for: languagePair.to),
              let text = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }

        let urlString = switch self {
        case .deepL:
            "https://www.deepl.com/en/translator#\(source)/\(target)/\(text)"
        case .google: "https://translate.google.com/?hl=en&sl=\(source)&tl=\(target)&text=\(text)&op=translate"
        case .lara: "https://laratranslate.com/translate?source=\(source)&text=\(text)&target=\(target)"
        case .reverso: "https://www.reverso.net/text-translation#sl=\(source)&tl=\(target)&text=\(text)"
        }

        return .init(string: urlString)
    }
}

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
        case .reverso: ReversoTranslator()
        case .lara: LaraTranslator()
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
        case .reverso: "https://www.reverso.net/text-translation"
        case .lara: "https://laratranslate.com/translate"
        }

        return .init(string: urlString)
    }

    // MARK: - Methods

    func requestURL(
        _ text: String,
        languagePair: LanguagePair
    ) -> URL? {
        guard let source = identifier(for: languagePair.from),
              let target = identifier(for: languagePair.to),
              let text = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }

        let urlString = switch self {
        case .deepL: "https://www.deepl.com/en/translator#\(source)/\(target)/\(text)"
        case .google: "https://translate.google.com/?hl=en&sl=\(source)&tl=\(target)&text=\(text)&op=translate"
        case .reverso: "https://www.reverso.net/text-translation#sl=\(source)&tl=\(target)&text=\(text)"
        case .lara: "https://laratranslate.com/translate?source=\(source)&text=\(text)&target=\(target)"
        }

        return .init(string: urlString)
    }

    private func identifier(for languageCode: String) -> String? {
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
}

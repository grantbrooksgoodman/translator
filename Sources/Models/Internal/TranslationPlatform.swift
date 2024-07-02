//
//  TranslationPlatform.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

enum TranslationPlatform: Codable, Equatable {
    // MARK: - Type Aliases

    private typealias Strings = Constants.Strings.TranslationPlatform

    // MARK: - Cases

    case deepL
    case google
    case reverso

    // MARK: - Properties

    var alternateJavaScriptString: String {
        switch self {
        case .deepL:
            return Strings.deepLAlternateJavaScriptString

        case .google:
            return Strings.googleAlternateJavaScriptString

        case .reverso:
            return Strings.reversoAlternateJavaScriptString
        }
    }

    var instance: any Translatorable {
        switch self {
        case .deepL: DeepLTranslator()
        case .google: GoogleTranslator()
        case .reverso: ReversoTranslator()
        }
    }

    var javaScriptString: String {
        switch self {
        case .deepL:
            return Strings.deepLJavaScriptString

        case .google:
            return Strings.googleJavaScriptString

        case .reverso:
            return Strings.reversoJavaScriptString
        }
    }

    // MARK: - Methods

    func requestURL(
        _ text: String,
        languagePair: LanguagePair
    ) -> URL? {
        guard let source = identifier(for: languagePair.from),
              let target = identifier(for: languagePair.to),
              let text = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }

        switch self {
        case .deepL:
            return .init(string: "https://www.deepl.com/en/translator#\(source)/\(target)/\(text)")

        case .google:
            return .init(string: "https://translate.google.com/?hl=en&sl=\(source)&tl=\(target)&text=\(text)&op=translate")

        case .reverso:
            return .init(string: "https://www.reverso.net/text-translation#sl=\(source)&tl=\(target)&text=\(text)")
        }
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

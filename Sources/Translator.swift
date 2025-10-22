//
//  Translator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable identifier_name line_length

/* Native */
import Foundation

// MARK: - Type Aliases

typealias Config = Translator.Config

// MARK: - Translator

public struct Translator {
    private init() {}
}

public extension Translator {
    /* MARK: Types */

    final class Config {
        /* MARK: Properties */

        public static let shared = Config()

        public private(set) var archiverDelegate: TranslationArchiverDelegate?
        public private(set) var loggerDelegate: TranslationLoggerDelegate?

        /* MARK: Init */

        private init() {}

        /* MARK: Delegate Registration */

        public func registerArchiverDelegate(_ archiverDelegate: TranslationArchiverDelegate) {
            self.archiverDelegate = archiverDelegate
        }

        public func registerLoggerDelegate(_ loggerDelegate: TranslationLoggerDelegate) {
            self.loggerDelegate = loggerDelegate
        }
    }

    /* MARK: Methods */

    internal static func descriptor(_ error: Error) -> String {
        func descriptor(_ error: NSError) -> String {
            return "\(error.localizedDescription) (\(error.code))"
        }

        typealias Strings = Constants.Strings.Core

        guard let userInfo = error._userInfo as? NSDictionary,
              let errorMessage = userInfo[
                  Strings.javaScriptExceptionMessageErrorUserInfoKey
              ] as? String ?? userInfo[
                  Strings.nsHelpAnchorErrorUserInfoKey
              ] as? String else { return descriptor(error as NSError) }

        return "\(errorMessage) (\((error as NSError).code))"
    }
}

// MARK: - Constants

enum Constants {
    // MARK: - String

    enum Strings {
        /* MARK: Core */

        enum Core {
            public static let googleConsentJavaScriptString = "document.getElementsByClassName('VfPpkd-RLmnJb')[3].click();"
            public static let googleConsentURLString = "https://consent.google.com/"
            public static let javaScriptExceptionMessageErrorUserInfoKey = "WKJavaScriptExceptionMessage"
            public static let nsHelpAnchorErrorUserInfoKey = "NSHelpAnchor"
            public static let processingDelimiter = "⌘"
            public static let processingToken = "⁂"
        }

        /* MARK: LocalTranslationArchiver */

        enum LocalTranslationArchiver {
            public static let archiveUserDefaultsKey = "translationArchive"
        }

        /* MARK: TranslationPlatform */

        enum TranslationPlatform {
            public static let deepLJavaScriptString = "var result = document.querySelectorAll('[aria-labelledby=\"translation-results-heading\"]'); result[result.length - 1].innerText;"
            public static let deepLAlternateJavaScriptString = "var result = document.querySelectorAll('[aria-labelledby=\"translation-target-heading\"]'); result[result.length - 1].innerText"

            public static let googleJavaScriptString = "document.getElementsByClassName('lRu31')[0].innerText;"
            public static let googleAlternateJavaScriptString = "document.getElementsByClassName('lRu31')[1].innerText;"

            public static let reversoJavaScriptString = "document.getElementsByClassName('text__translation')[0].innerText;"
            public static let reversoAlternateJavaScriptString = "document.getElementsByClassName('translation-input__main translation-input__result')[0].innerText;"
        }
    }
}

// swiftlint:enable identifier_name line_length

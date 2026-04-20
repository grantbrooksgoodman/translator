//
//  Translator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable identifier_name line_length

/* Native */
import Foundation

// MARK: - Translator

/// The top-level namespace for the Translator framework.
///
/// `Translator` provides access to the framework's configuration through
/// the ``config`` property. Use it to register custom delegates that
/// control caching and logging behavior:
///
/// ```swift
/// Translator.config.registerArchiverDelegate(myArchiver)
/// Translator.config.registerLoggerDelegate(myLogger)
/// ```
///
/// For performing translations, use ``TranslationService`` directly.
public enum Translator {
    /// The shared configuration object for the Translator framework.
    ///
    /// Use this property to register delegates that customize how the
    /// framework caches translations and reports diagnostic messages.
    public static let config = Config.shared
}

public extension Translator {
    /* MARK: Types */

    /// The configuration object for the Translator framework.
    ///
    /// Use `Config` to register the delegates that control how the
    /// framework caches completed translations and routes diagnostic
    /// messages. Access the shared instance through ``Translator/config``:
    ///
    /// ```swift
    /// Translator.config.registerArchiverDelegate(myArchiver)
    /// Translator.config.registerLoggerDelegate(myLogger)
    /// ```
    ///
    /// When no archiver delegate is registered, ``TranslationService``
    /// falls back to ``LocalTranslationArchiver``, which persists
    /// translations in `UserDefaults`. When no logger delegate is
    /// registered, diagnostic messages are silently discarded.
    ///
    /// - Important: `Config` is safe to access from any thread or
    ///   concurrency context. All property access and delegate
    ///   registration are internally serialized.
    final class Config: @unchecked Sendable {
        /* MARK: Properties */

        fileprivate static let shared = Config()

        private let ioLock = NSRecursiveLock()

        private var _archiverDelegate: TranslationArchiverDelegate?
        private var _loggerDelegate: TranslationLoggerDelegate?

        /* MARK: Computed Properties */

        /// The registered translation archiver delegate, or `nil` if
        /// none has been registered.
        ///
        /// When this value is `nil`, ``TranslationService`` uses
        /// ``LocalTranslationArchiver`` as its default caching strategy.
        public var archiverDelegate: TranslationArchiverDelegate? {
            ioLock.lock()
            defer { ioLock.unlock() }
            return _archiverDelegate
        }

        /// The registered translation logger delegate, or `nil` if
        /// none has been registered.
        ///
        /// When this value is `nil`, the framework silently discards
        /// all diagnostic messages.
        public var loggerDelegate: TranslationLoggerDelegate? {
            ioLock.lock()
            defer { ioLock.unlock() }
            return _loggerDelegate
        }

        /* MARK: Init */

        private init() {}

        /* MARK: Delegate Registration */

        /// Registers a custom archiver delegate for caching translations.
        ///
        /// Once registered, ``TranslationService`` consults this delegate
        /// before every network request and stores each successful
        /// translation through it. Calling this method replaces any
        /// previously registered archiver.
        ///
        /// ```swift
        /// Translator.config.registerArchiverDelegate(DatabaseArchiver())
        /// ```
        ///
        /// - Parameter archiverDelegate: The delegate to use for
        ///   translation caching.
        public func registerArchiverDelegate(
            _ archiverDelegate: TranslationArchiverDelegate
        ) {
            ioLock.lock()
            defer { ioLock.unlock() }
            _archiverDelegate = archiverDelegate
        }

        /// Registers a custom logger delegate for receiving diagnostic
        /// messages.
        ///
        /// Once registered, the framework routes internal errors and
        /// notable events to this delegate. Calling this method replaces
        /// any previously registered logger.
        ///
        /// ```swift
        /// Translator.config.registerLoggerDelegate(TranslationLogger())
        /// ```
        ///
        /// - Parameter loggerDelegate: The delegate to use for diagnostic
        ///   logging.
        public func registerLoggerDelegate(
            _ loggerDelegate: TranslationLoggerDelegate
        ) {
            ioLock.lock()
            defer { ioLock.unlock() }
            _loggerDelegate = loggerDelegate
        }
    }

    /* MARK: Methods */

    internal static func descriptor(_ error: Error) -> String {
        func descriptor(_ error: NSError) -> String {
            "\(error.localizedDescription) (\(error.code))"
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

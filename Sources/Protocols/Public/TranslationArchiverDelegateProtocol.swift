//
//  TranslationArchiverDelegateProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A protocol you adopt to provide custom translation caching behavior.
///
/// Adopt `TranslationArchiverDelegate` to replace the default
/// ``LocalTranslationArchiver`` with your own caching strategy.
/// ``TranslationService`` consults the registered archiver before every
/// network request, and stores each successful translation through it
/// afterward.
///
/// To create a custom archiver, declare a type that conforms to this
/// protocol and implement all required methods:
///
/// ```swift
/// final class DatabaseArchiver: TranslationArchiverDelegate {
///     func addValue(_ translation: Translation) { /* ... */ }
///     func addValues(_ translations: Set<Translation>) { /* ... */ }
///     func getValue(
///         inputValueEncodedHash hash: String,
///         languagePair: LanguagePair
///     ) -> Translation? { /* ... */ }
///     func removeValue(
///         inputValueEncodedHash hash: String,
///         languagePair: LanguagePair
///     ) { /* ... */ }
///     func clearArchive() { /* ... */ }
/// }
/// ```
///
/// Register your archiver through ``Translator/Config``:
///
/// ```swift
/// Translator.config.registerArchiverDelegate(DatabaseArchiver())
/// ```
///
/// When no custom archiver is registered, ``TranslationService`` falls back
/// to ``LocalTranslationArchiver``, which persists translations in
/// `UserDefaults`.
///
/// - Important: Conforming types must be safe to call from any thread or
///   concurrency context. ``TranslationService`` may invoke archiver
///   methods concurrently from multiple tasks.
// swiftlint:disable:next class_delegate_protocol
public protocol TranslationArchiverDelegate: Sendable {
    // MARK: - Add Value

    /// Stores a single translation in the archive.
    ///
    /// ``TranslationService`` calls this method after each successful
    /// translation to cache the result.
    ///
    /// - Parameter translation: The ``Translation`` to store.
    func addValue(_ translation: Translation)

    /// Stores a set of translations in the archive.
    ///
    /// Use this method to persist multiple translations in a single
    /// operation.
    ///
    /// - Parameter translations: The set of ``Translation`` values to store.
    func addValues(_ translations: Set<Translation>)

    // MARK: - Get Value

    /// Retrieves a cached translation matching the given input hash and
    /// language pair.
    ///
    /// ``TranslationService`` calls this method before performing a network
    /// request. Return the cached ``Translation`` if one exists, or `nil`
    /// to indicate a cache miss.
    ///
    /// - Parameters:
    ///   - hash: The encoded hash of the original input string.
    ///   - languagePair: The ``LanguagePair`` to match against.
    ///
    /// - Returns: The matching ``Translation``, or `nil` if no cached
    ///   translation is found.
    func getValue(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    ) -> Translation?

    // MARK: - Remove Value

    /// Removes a cached translation matching the given input hash and
    /// language pair.
    ///
    /// ``TranslationService`` calls this method to evict translations that
    /// fail validation upon retrieval. If no matching translation exists,
    /// this method should do nothing.
    ///
    /// - Parameters:
    ///   - hash: The encoded hash of the original input string to remove.
    ///   - languagePair: The ``LanguagePair`` to match against.
    func removeValue(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    )

    // MARK: - Clear Archive

    /// Removes all cached translations from the archive.
    func clearArchive()
}

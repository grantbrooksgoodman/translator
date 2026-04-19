//
//  LocalTranslationArchiver.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A persistent, on-device store for caching completed translations.
///
/// `LocalTranslationArchiver` saves and retrieves ``Translation`` values using
/// `UserDefaults` as its backing store. It serves as the default archiver for
/// ``TranslationService`` when no custom ``TranslationArchiverDelegate`` is
/// registered through ``Translator/Config``.
///
/// Access the shared archiver instance using the ``shared`` property:
///
/// ```swift
/// let archiver = LocalTranslationArchiver.shared
/// ```
///
/// All read and write operations are serialized using an internal lock,
/// making the archiver safe to call from any thread or concurrency context.
///
/// - Note: To provide a custom caching strategy, implement the
///   ``TranslationArchiverDelegate`` protocol and register your implementation
///   using ``Translator/Config/registerArchiverDelegate(_:)``.
///
/// - Important: Because this archiver uses `UserDefaults`, it is best suited
///   for moderate amounts of cached data. For large-scale translation caching,
///   consider implementing a custom archiver backed by a database or file-based
///   storage.
public final class LocalTranslationArchiver: TranslationArchiverDelegate, @unchecked Sendable {
    // MARK: - Type Aliases

    private typealias Strings = Constants.Strings.LocalTranslationArchiver

    // MARK: - Properties

    /// The shared local translation archiver instance.
    public static let shared = LocalTranslationArchiver()

    private let defaults = UserDefaults.standard
    private let ioLock = NSRecursiveLock()
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    // MARK: - Init

    private init() {}

    // MARK: - Addition

    /// Adds a single translation to the archive.
    ///
    /// If a translation with the same input already exists in the archive, it is
    /// replaced with the new value.
    ///
    /// - Parameter translation: The ``Translation`` to store.
    public func addValue(_ translation: Translation) {
        ioLock.lock()
        defer { ioLock.unlock() }

        var archive = getArchive()
        archive.insert(translation)
        setArchive(archive)
    }

    /// Adds a set of translations to the archive.
    ///
    /// Use this method to store multiple translations in a single operation. Existing
    /// entries in the archive are preserved; the new translations are merged in.
    ///
    /// - Parameter translations: A set of ``Translation`` values to store.
    public func addValues(_ translations: Set<Translation>) {
        ioLock.lock()
        defer { ioLock.unlock() }

        var archive = getArchive()
        archive.formUnion(translations)
        setArchive(archive)
    }

    // MARK: - Retrieval

    /// Retrieves a cached translation matching the given input hash and
    /// language pair.
    ///
    /// The archiver matches translations by comparing the encoded hash of the
    /// original input value and the target language of the language pair.
    ///
    /// - Parameters:
    ///   - hash: The encoded hash of the original input string to look up.
    ///   - languagePair: The language pair to match against. Only the target
    ///     language is used for matching.
    ///
    /// - Returns: The matching ``Translation``, or `nil` if no cached
    ///   translation is found.
    public func getValue(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    ) -> Translation? {
        ioLock.lock()
        defer { ioLock.unlock() }

        let archive = getArchive()
        return archive.first(where: {
            $0.input.value.encodedHash == hash &&
                $0.languagePair.to == languagePair.to
        })
    }

    // MARK: - Removal

    /// Removes all cached translations from the archive.
    ///
    /// After calling this method, subsequent calls to
    /// ``getValue(inputValueEncodedHash:languagePair:)`` return `nil` until
    /// new translations are added.
    public func clearArchive() {
        ioLock.lock()
        defer { ioLock.unlock() }
        setArchive([])
    }

    /// Removes a cached translation matching the given input hash and
    /// language pair.
    ///
    /// If no matching translation exists in the archive, this method
    /// does nothing.
    ///
    /// - Parameters:
    ///   - hash: The encoded hash of the original input string to remove.
    ///   - languagePair: The language pair to match against.
    public func removeValue(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    ) {
        ioLock.lock()
        defer { ioLock.unlock() }

        if let value = getValue(
            inputValueEncodedHash: hash,
            languagePair: languagePair
        ) {
            var archive = getArchive()
            archive.remove(value)
            setArchive(archive)
        }
    }

    // MARK: - Auxiliary

    private func getArchive() -> Set<Translation> {
        guard let data = defaults.object(
            forKey: Strings.archiveUserDefaultsKey
        ) as? Data else { return [] }

        do {
            return try jsonDecoder.decode(
                Set<Translation>.self,
                from: data
            )
        } catch {
            Translator.config.loggerDelegate?.log(
                Translator.descriptor(error),
                sender: self,
                fileName: #fileID,
                function: #function,
                line: #line
            )
            return []
        }
    }

    private func setArchive(_ archive: Set<Translation>) {
        do {
            try defaults.set(
                jsonEncoder.encode(archive),
                forKey: Strings.archiveUserDefaultsKey
            )
        } catch {
            Translator.config.loggerDelegate?.log(
                Translator.descriptor(error),
                sender: self,
                fileName: #fileID,
                function: #function,
                line: #line
            )
        }
    }
}

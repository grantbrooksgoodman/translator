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

    /// Serializes disk writes off the calling thread; lookups and mutations
    /// operate on the in-memory archive and never wait for the disk.
    private let persistenceQueue = DispatchQueue(
        label: "us.neotechnica.translator.archiver-persistence",
        qos: .utility
    )

    /// Maps `"<input value hash>|<source language>-<target language>"` to its
    /// translation for constant-time lookups, avoiding a per-entry hash
    /// computation on every query.
    private var archiveIndex = [String: Translation]()

    /// The decoded archive, loaded from disk at most once per launch.
    private var cachedArchive: Set<Translation>?

    // MARK: - Init

    private init() {}

    // MARK: - Preload

    /// Loads and indexes the archive from disk ahead of the first lookup.
    ///
    /// Call this method early in the app lifecycle (e.g. at launch) to move
    /// the one-time cost of decoding and indexing the archive off the first
    /// translation request. Calling it more than once has no effect.
    public func preload() {
        persistenceQueue.async {
            self.ioLock.lock()
            defer { self.ioLock.unlock() }
            _ = self.loadArchiveIfNeeded()
        }
    }

    // MARK: - Addition

    /// Adds a single translation to the archive.
    ///
    /// If a translation with the same input and language pair already exists
    /// in the archive, it is replaced with the new value.
    ///
    /// - Parameter translation: The ``Translation`` to store.
    public func addValue(_ translation: Translation) {
        ioLock.lock()
        defer { ioLock.unlock() }

        var archive = loadArchiveIfNeeded()
        insert(
            translation,
            into: &archive
        )

        cachedArchive = archive
        persistArchive(archive)
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

        var archive = loadArchiveIfNeeded()
        for translation in translations {
            insert(
                translation,
                into: &archive
            )
        }

        cachedArchive = archive
        persistArchive(archive)
    }

    // MARK: - Retrieval

    /// Retrieves a cached translation matching the given input hash and
    /// language pair.
    ///
    /// The archiver matches translations by comparing the encoded hash of the
    /// original input value and both languages of the language pair.
    ///
    /// - Parameters:
    ///   - hash: The encoded hash of the original input string to look up.
    ///   - languagePair: The language pair to match against.
    ///
    /// - Returns: The matching ``Translation``, or `nil` if no cached
    ///   translation is found.
    public func getValue(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    ) -> Translation? {
        ioLock.lock()
        defer { ioLock.unlock() }

        _ = loadArchiveIfNeeded()
        return archiveIndex[indexKey(
            inputValueEncodedHash: hash,
            languagePair: languagePair
        )]
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

        cachedArchive = []
        archiveIndex = [:]
        persistArchive([])
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

        guard let value = getValue(
            inputValueEncodedHash: hash,
            languagePair: languagePair
        ) else { return }

        var archive = loadArchiveIfNeeded()
        archive.remove(value)
        archiveIndex[indexKey(
            inputValueEncodedHash: hash,
            languagePair: languagePair
        )] = nil

        cachedArchive = archive
        persistArchive(archive)
    }

    // MARK: - Auxiliary

    private func indexKey(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    ) -> String {
        "\(hash)|\(languagePair.string)"
    }

    private func indexKey(for translation: Translation) -> String {
        indexKey(
            inputValueEncodedHash: translation.input.value.encodedHash,
            languagePair: translation.languagePair
        )
    }

    /// Inserts the translation into both the archive and the index, replacing
    /// any existing translation for the same input and language pair.
    private func insert(
        _ translation: Translation,
        into archive: inout Set<Translation>
    ) {
        let key = indexKey(for: translation)
        if let existingTranslation = archiveIndex[key] {
            archive.remove(existingTranslation)
        }

        archive.insert(translation)
        archiveIndex[key] = translation
    }

    private func loadArchiveIfNeeded() -> Set<Translation> {
        if let cachedArchive { return cachedArchive }

        var archive = Set<Translation>()
        defer {
            cachedArchive = archive
            archiveIndex = archive.reduce(into: [String: Translation]()) { index, translation in
                index[indexKey(for: translation)] = translation
            }
        }

        guard let data = defaults.object(
            forKey: Strings.archiveUserDefaultsKey
        ) as? Data else {
            return archive
        }

        do {
            archive = try jsonDecoder.decode(
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
        }

        return archive
    }

    /// Encodes and writes the archive on a background queue, keeping disk
    /// I/O off the translation path. Writes are serialized in submission
    /// order, so the last snapshot always wins.
    private func persistArchive(_ archive: Set<Translation>) {
        persistenceQueue.async {
            do {
                try self.defaults.set(
                    JSONEncoder().encode(archive),
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
}

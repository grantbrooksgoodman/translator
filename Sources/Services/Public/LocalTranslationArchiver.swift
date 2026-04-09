//
//  LocalTranslationArchiver.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public final class LocalTranslationArchiver: TranslationArchiverDelegate, @unchecked Sendable {
    // MARK: - Type Aliases

    private typealias Strings = Constants.Strings.LocalTranslationArchiver

    // MARK: - Properties

    public static let shared = LocalTranslationArchiver()

    private let defaults = UserDefaults.standard
    private let ioLock = NSRecursiveLock()
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    // MARK: - Init

    private init() {}

    // MARK: - Addition

    public func addValue(_ translation: Translation) {
        ioLock.lock()
        defer { ioLock.unlock() }

        var archive = getArchive()
        archive.insert(translation)
        setArchive(archive)
    }

    public func addValues(_ translations: Set<Translation>) {
        ioLock.lock()
        defer { ioLock.unlock() }

        var archive = getArchive()
        archive.formUnion(translations)
        setArchive(archive)
    }

    // MARK: - Retrieval

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

    public func clearArchive() {
        ioLock.lock()
        defer { ioLock.unlock() }
        setArchive([])
    }

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
            Config.shared.loggerDelegate?.log(
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
            Config.shared.loggerDelegate?.log(
                Translator.descriptor(error),
                sender: self,
                fileName: #fileID,
                function: #function,
                line: #line
            )
        }
    }
}

//
//  LocalTranslationArchiver.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// TODO: Ensure using languagePair.to is the correct logic path. Requires some thought.
// TODO: Use different suite for UserDefaults.

public final class LocalTranslationArchiver: TranslationArchiverDelegate {
    // MARK: - Type Aliases

    private typealias Strings = Constants.Strings.LocalTranslationArchiver

    // MARK: - Properties

    public static let shared = LocalTranslationArchiver()

    private let defaults = UserDefaults.standard
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    // MARK: - Computed Properties

    private var archive: Set<Translation> {
        get { getArchive() }
        set { setArchive(newValue) }
    }

    // MARK: - Init

    private init() {}

    // MARK: - Addition

    public func addValue(_ translation: Translation) {
        archive.insert(translation)
    }

    public func addValues(_ translations: Set<Translation>) {
        archive.formUnion(translations)
    }

    // MARK: - Retrieval

    public func getValue(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    ) -> Translation? {
        archive.first(where: {
            $0.input.value.encodedHash == hash && $0.languagePair.to == languagePair.to
        })
    }

    // MARK: - Removal

    public func clearArchive() {
        archive = []
    }

    public func removeValue(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    ) {
        if let value = getValue(
            inputValueEncodedHash: hash,
            languagePair: languagePair
        ) {
            archive.remove(value)
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

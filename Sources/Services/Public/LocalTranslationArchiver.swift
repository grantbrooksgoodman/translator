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

    // MARK: - Computed Properties

    private var archive: [Translation] {
        get { getArchive() }
        set { setArchive(newValue) }
    }

    // MARK: - Init

    private init() {}

    // MARK: - Addition

    public func addValue(_ translation: Translation) {
        archive.removeAll(where: { $0 == translation })
        archive.append(translation)
    }

    // MARK: - Retrieval

    public func getValue(inputValueEncodedHash hash: String, languagePair: LanguagePair) -> Translation? {
        archive.first(where: { $0.input.value.encodedHash == hash && $0.languagePair.to == languagePair.to })
    }

    // MARK: - Removal

    public func clearArchive() {
        archive = []
    }

    public func removeValue(inputValueEncodedHash hash: String, languagePair: LanguagePair) {
        archive.removeAll(where: { $0.input.value.encodedHash == hash && $0.languagePair.to == languagePair.to })
    }

    // MARK: - Auxiliary

    private func getArchive() -> [Translation] {
        guard let data = UserDefaults.standard.object(forKey: Strings.archiveUserDefaultsKey) as? Data else { return [] }
        let jsonDecoder = JSONDecoder()

        do {
            let decoded: [Translation] = try jsonDecoder.decode([Translation].self, from: data)
            return decoded
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

    private func setArchive(_ archive: [Translation]) {
        let jsonEncoder = JSONEncoder()

        do {
            let encoded: Data = try jsonEncoder.encode(archive)
            UserDefaults.standard.set(encoded, forKey: Strings.archiveUserDefaultsKey)
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

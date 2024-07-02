//
//  TranslationArchiverDelegateProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// swiftlint:disable:next class_delegate_protocol
public protocol TranslationArchiverDelegate {
    // MARK: - Add Value

    func addValue(_ translation: Translation)

    // MARK: - Get Value

    func getValue(inputValueEncodedHash hash: String, languagePair: LanguagePair) -> Translation?

    // MARK: - Remove Value

    func removeValue(inputValueEncodedHash hash: String, languagePair: LanguagePair)

    // MARK: - Clear Archive

    func clearArchive()
}

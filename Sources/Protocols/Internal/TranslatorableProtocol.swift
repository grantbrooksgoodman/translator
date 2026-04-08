//
//  TranslatorableProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

@MainActor
protocol Translatorable: Sendable {
    // MARK: - Properties

    var platform: TranslationPlatform { get }

    // MARK: - Methods

    func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Result<Translation, TranslationError>
}

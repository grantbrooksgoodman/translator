//
//  Translation.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct Translation: Codable, Hashable {
    // MARK: - Properties

    public let input: TranslationInput
    public let languagePair: LanguagePair
    public let output: String

    // MARK: - Init

    public init(
        input: TranslationInput,
        output: String,
        languagePair: LanguagePair
    ) {
        self.input = input
        self.output = output
        self.languagePair = languagePair
    }
}

extension Translation: Validatable {
    public var isWellFormed: Bool {
        let isInputValid = input.isWellFormed
        let isLanguagePairValid = languagePair.isWellFormed
        let isOutputValid = TranslationInput(output).isWellFormed
        return isInputValid && isLanguagePairValid && isOutputValid
    }
}

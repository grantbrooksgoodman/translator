//
//  TranslationInput.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct TranslationInput: Codable, Equatable {
    // MARK: - Properties

    public let original: String
    public let alternate: String?

    // MARK: - Computed Properties

    public var value: String { alternate ?? original }

    // MARK: - Init

    public init(_ original: String, alternate: String?) {
        self.original = original
        self.alternate = alternate
    }

    public init(_ original: String) {
        self.init(original, alternate: nil)
    }
}

extension TranslationInput: Validatable {
    public var isWellFormed: Bool { !value.isBlank }
}

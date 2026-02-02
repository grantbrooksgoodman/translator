//
//  LanguagePair.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct LanguagePair: Codable, Hashable {
    // MARK: - Properties

    public let from: String
    public let to: String

    // MARK: - Computed Properties

    public var isIdempotent: Bool { from == to }
    public var string: String { "\(from)-\(to)" }

    // MARK: - Init

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }

    public init?(_ string: String) {
        let components = string.components(separatedBy: "-")
        guard !components.isEmpty else { return nil }

        let fromValue = components[0].lowercasedTrimmingWhitespaceAndNewlines
        guard components.count > 1 else {
            self.init(from: fromValue, to: fromValue)
            return
        }

        let toValue = components[1 ... components.count - 1].joined().lowercasedTrimmingWhitespaceAndNewlines
        self.init(from: fromValue, to: toValue)
    }
}

extension LanguagePair: Validatable {
    public var isWellFormed: Bool {
        let isFromValid = !from.isBlank && from.count == 2
        let isToValid = !to.isBlank && to.count == 2
        return isFromValid && isToValid
    }
}

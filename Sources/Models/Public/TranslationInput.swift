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

    var withTokenizedDetectorAttributes: TranslationInput {
        typealias Strings = Constants.Strings.Core
        var stringValue = value

        let detectorType: NSTextCheckingResult.CheckingType = [
            .address,
            .link,
            .phoneNumber,
        ]

        guard let dataDetector = try? NSDataDetector(types: detectorType.rawValue) else { return self }

        for taggableString in dataDetector.matches(
            in: stringValue,
            range: .init(location: 0, length: stringValue.utf16.count)
        ).compactMap({ Range($0.range, in: value) }).compactMap({ String(value[$0]) }) {
            stringValue = stringValue.replacingOccurrences(
                of: taggableString,
                with: "\(Strings.processingDelimiter)\(taggableString)\(Strings.processingDelimiter)"
            )
        }

        guard stringValue != value else { return self }
        return .init(stringValue)
    }

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

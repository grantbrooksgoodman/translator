//
//  Array+PublicExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Array where Element == Translation {
    var isWellFormed: Bool {
        !isEmpty && allSatisfy(\.isWellFormed)
    }
}

public extension Array where Element == TranslationInput {
    var isWellFormed: Bool {
        !isEmpty && allSatisfy(\.isWellFormed)
    }
}

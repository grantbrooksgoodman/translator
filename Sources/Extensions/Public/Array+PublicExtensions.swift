//
//  Array+PublicExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension [Translation] {
    /// A Boolean value that indicates whether the array is non-empty and
    /// every element passes validation.
    var isWellFormed: Bool {
        !isEmpty && allSatisfy(\.isWellFormed)
    }
}

public extension [TranslationInput] {
    /// A Boolean value that indicates whether the array is non-empty and
    /// every element passes validation.
    var isWellFormed: Bool {
        !isEmpty && allSatisfy(\.isWellFormed)
    }
}

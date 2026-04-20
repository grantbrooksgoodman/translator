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
    ///
    /// This property returns `true` when the array contains at least one
    /// element and every ``Translation`` in the array satisfies
    /// ``Translation/isWellFormed``. An empty array always returns
    /// `false`.
    var isWellFormed: Bool {
        !isEmpty && allSatisfy(\.isWellFormed)
    }
}

public extension [TranslationInput] {
    /// A Boolean value that indicates whether the array is non-empty and
    /// every element passes validation.
    ///
    /// This property returns `true` when the array contains at least one
    /// element and every ``TranslationInput`` in the array satisfies
    /// ``TranslationInput/isWellFormed``. An empty array always returns
    /// `false`.
    ///
    /// ``TranslationService/getTranslations(_:languagePair:)`` checks
    /// this property before processing a batch and returns
    /// ``TranslationError/invalidArguments`` when it is `false`.
    var isWellFormed: Bool {
        !isEmpty && allSatisfy(\.isWellFormed)
    }
}

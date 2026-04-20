//
//  String+PublicExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension String: EncodedHashable {
    /// The components used to compute this string's encoded hash.
    ///
    /// For `String`, the hash factors array contains only the string
    /// itself. The framework uses the resulting encoded hash to identify
    /// cached translations in the archive.
    public var hashFactors: [String] { [self] }
}

public extension String {
    /// A Boolean value that indicates whether the string contains at
    /// least one Unicode letter character.
    ///
    /// A character qualifies as a letter only if it belongs to the
    /// Unicode `letters` category and is not a control character,
    /// illegal character, non-base character, punctuation mark, or
    /// symbol.
    ///
    /// ``TranslationService`` uses this property to determine whether
    /// the input contains translatable content. Strings composed
    /// entirely of numbers, punctuation, or whitespace return `false`
    /// and are returned unchanged without a network request.
    var containsLetters: Bool {
        unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar)
                && !(CharacterSet.controlCharacters.contains(scalar)
                    || CharacterSet.illegalCharacters.contains(scalar)
                    || CharacterSet.nonBaseCharacters.contains(scalar)
                    || CharacterSet.punctuationCharacters.contains(scalar)
                    || CharacterSet.symbols.contains(scalar))
        }
    }
}

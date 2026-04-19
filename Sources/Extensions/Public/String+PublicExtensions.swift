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
    public var hashFactors: [String] { [self] }
}

public extension String {
    /// A Boolean value that indicates whether the string contains at least
    /// one Unicode letter that is not a control character, symbol, or
    /// punctuation mark.
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

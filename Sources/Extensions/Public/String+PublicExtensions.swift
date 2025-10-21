//
//  String+PublicExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension String: EncodedHashable {
    public var hashFactors: [String] { [self] }
}

public extension String {
    var containsLetters: Bool {
        unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar)
                && !(CharacterSet.symbols.contains(scalar)
                    || CharacterSet.nonBaseCharacters.contains(scalar)
                    || CharacterSet.controlCharacters.contains(scalar)
                    || CharacterSet.punctuationCharacters.contains(scalar)
                    || CharacterSet.illegalCharacters.contains(scalar))
        }
    }
}

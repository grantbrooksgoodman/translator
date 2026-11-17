//
//  Constants+LocalTranslationArchiver.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// MARK: - CGFloat

extension Constants.CGFloats {
    enum LocalTranslationArchiver {
        static let writeDelayMilliseconds: CGFloat = 1000
    }
}

// MARK: - String

extension Constants.Strings {
    enum LocalTranslationArchiver {
        static let archiveUserDefaultsKey = "translationArchive"
    }
}

//
//  DeepLTranslator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

final class DeepLTranslator: BaseTranslator, Translatorable {
    // MARK: - Properties

    var platform: TranslationPlatform = .deepL

    // MARK: - Init

    init() {
        super.init(platform: platform)
    }
}

//
//  Constants+TranslationPlatform.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable line_length

/* Native */
import Foundation

// MARK: - String

extension Constants.Strings {
    enum TranslationPlatform {
        static let deepLAlternateJavaScriptString = "var result = document.querySelectorAll('[aria-labelledby=\"translation-target-heading\"]'); result[result.length - 1].innerText;"
        static let deepLJavaScriptString = "var result = document.querySelectorAll('[aria-labelledby=\"translation-results-heading\"]'); result[result.length - 1].innerText;"

        static let googleAlternateJavaScriptString = "document.getElementsByClassName('lRu31')[1].innerText;"
        static let googleJavaScriptString = "document.getElementsByClassName('lRu31')[0].innerText;"

        static let laraJavaScriptString = "document.getElementsByClassName('knownFragmentElementNode')[0].innerText;"

        static let reversoAlternateJavaScriptString = "document.getElementsByClassName('translation-input__main translation-input__result')[0].innerText;"
        static let reversoJavaScriptString = "document.getElementsByClassName('textarea translation-box__translated-text translation-box__translated-text_favorite')[0].innerText;"
    }
}

// swiftlint:enable line_length

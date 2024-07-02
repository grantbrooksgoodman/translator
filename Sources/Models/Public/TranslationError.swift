//
//  TranslationError.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum TranslationError: LocalizedError {
    // MARK: - Cases

    case evaluateJavaScriptFailed(String? = nil)
    case failedToGenerateRequestURL
    case invalidArguments
    case javaScriptError(String)
    case malformedTranslationResult
    case timedOut
    case webViewNavigationFailed(String)
    case unknown(String? = nil)

    // MARK: - Properties

    public var errorDescription: String? {
        switch self {
        case let .evaluateJavaScriptFailed(errorDescription):
            return "Failed to evaluate JavaScript: \(errorDescription ?? "An unknown error occurred.")"

        case .failedToGenerateRequestURL:
            return "Failed to generate request URL."

        case .invalidArguments:
            return "Passed arguments fail validation."

        case let .javaScriptError(errorDescription):
            return "JavaScript error occurred: \(errorDescription)"

        case .malformedTranslationResult:
            return "Malformed translation result."

        case .timedOut:
            return "The operation timed out. Please try again later."

        case let .webViewNavigationFailed(errorDescription):
            return "Web view navigation failed: \(errorDescription)"

        case let .unknown(errorDescription):
            return errorDescription ?? "An unknown error occurred."
        }
    }
}

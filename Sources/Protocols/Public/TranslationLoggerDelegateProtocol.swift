//
//  TranslationLoggerDelegateProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// swiftlint:disable:next class_delegate_protocol
public protocol TranslationLoggerDelegate: Sendable {
    func log(
        _ text: String,
        sender: Any,
        fileName: String,
        function: String,
        line: Int
    )
}

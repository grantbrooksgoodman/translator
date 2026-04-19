//
//  TranslationLoggerDelegateProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A protocol you adopt to receive diagnostic messages from the
/// translation system.
///
/// Adopt `TranslationLoggerDelegate` to observe internal
/// errors and diagnostic events produced by the Translator framework.
/// This is useful for routing translation-related messages into your
/// application's existing logging infrastructure.
///
/// To create a custom logger, declare a type that conforms to this protocol
/// and implement the ``log(_:sender:fileName:function:line:)`` method:
///
/// ```swift
/// final class TranslationLogger: TranslationLoggerDelegate {
///     func log(
///         _ text: String,
///         sender: Any,
///         fileName: String,
///         function: String,
///         line: Int
///     ) {
///         print("[\(fileName):\(line)] \(function) – \(text)")
///     }
/// }
/// ```
///
/// Register your logger through ``Translator/Config``:
///
/// ```swift
/// Translator.config.registerLoggerDelegate(TranslationLogger())
/// ```
///
/// When no logger is registered, diagnostic messages are silently
/// discarded.
///
/// - Important: Conforming types must be safe to call from any thread or
///   concurrency context.
// swiftlint:disable:next class_delegate_protocol
public protocol TranslationLoggerDelegate: Sendable {
    /// Processes a diagnostic message from the translation system.
    ///
    /// The framework calls this method when an internal error or notable
    /// event occurs – for example, when ``LocalTranslationArchiver`` fails
    /// to encode or decode its backing store.
    ///
    /// - Parameters:
    ///   - text: The diagnostic message.
    ///   - sender: The object that produced the message.
    ///   - fileName: The source file in which the message originated,
    ///     typically provided by the `#fileID` literal.
    ///   - function: The function in which the message originated,
    ///     typically provided by the `#function` literal.
    ///   - line: The line number at which the message originated,
    ///     typically provided by the `#line` literal.
    func log(
        _ text: String,
        sender: Any,
        fileName: String,
        function: String,
        line: Int
    )
}

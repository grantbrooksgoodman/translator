//
//  String+InternalExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension String {
    // MARK: - Properties

    var indexOfFirstLetter: Int? {
        for (index, character) in enumerated() {
            guard character.isLetter else { continue }
            return index
        }

        return nil
    }

    var isBlank: Bool {
        lowercasedTrimmingWhitespaceAndNewlines.isEmpty
    }

    var lowercasedTrimmingWhitespaceAndNewlines: String {
        lowercased().trimmingWhitespace.trimmingNewlines
    }

    var trimmingBorderedNewlines: String {
        trimmingLeadingNewlines.trimmingTrailingNewlines
    }

    var trimmingLeadingNewlines: String {
        var string = self
        while string.hasPrefix("\n") {
            string = string.dropPrefix()
        }
        return string
    }

    var trimmingTrailingNewlines: String {
        var string = self
        while string.hasSuffix("\n") {
            string = string.dropSuffix()
        }
        return string
    }

    var trimmingTrailingWhitespaceAndNewlines: String {
        trimmingTrailingWhitespace.trimmingTrailingNewlines
    }

    private var trimmingNewlines: String {
        replacingOccurrences(of: "\n", with: "")
    }

    private var trimmingTrailingWhitespace: String {
        var string = self
        while string.hasSuffix(" ") || string.hasSuffix("\u{00A0}") {
            string = string.dropSuffix()
        }
        return string
    }

    private var trimmingWhitespace: String {
        replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "")
    }

    // MARK: - Methods

    func capitalized(relativeTo comparator: String) -> String {
        guard let indexOfFirstLetter,
              indexOfFirstLetter == comparator.indexOfFirstLetter else { return self }

        let firstLetterInComparator: Character = .init(comparator.map { String($0) }[indexOfFirstLetter])
        var selfComponents = map { String($0) }

        if firstLetterInComparator.isUppercase {
            selfComponents[indexOfFirstLetter] = selfComponents[indexOfFirstLetter].uppercased()
        } else if firstLetterInComparator.isLowercase {
            selfComponents[indexOfFirstLetter] = selfComponents[indexOfFirstLetter].lowercased()
        }

        return selfComponents.joined()
    }

    func dropPrefix(_ dropping: Int = 1) -> String {
        .init(suffix(from: index(startIndex, offsetBy: dropping)))
    }

    func dropSuffix(_ dropping: Int = 1) -> String {
        .init(prefix(count - dropping))
    }

    func replacing(token: String, with slices: [String]) -> String {
        let components = components(separatedBy: token)
        var result = ""

        guard components.count - 1 > 0,
              slices.count == components.count - 1 else { return self }

        for (index, component) in components[0 ... components.count - 2].enumerated() {
            result += (component + slices[index].replacingOccurrences(of: token, with: ""))
        }

        return result + (components.last ?? "")
    }

    func tokenized(delimiter: String) -> (processed: String, slices: [String]) {
        typealias Strings = Constants.Strings.Core

        let components = components(separatedBy: delimiter)
        let extractedTokens = stride(
            from: 0,
            to: components.count - 1,
            by: 2
        ).reduce(into: [String]()) { result, index in
            guard components.count > index + 1 else { return }
            result.append(components[index + 1])
        }

        var processedString = self
        var validTokens = [String]()

        for token in extractedTokens {
            let canonizedToken = "\(delimiter)\(token)\(delimiter)"
            if extractedTokens.unique.count == extractedTokens.count {
                guard (processedString.components(separatedBy: canonizedToken).count - 1) > 0 else { continue }
            }

            guard canonizedToken != "\(delimiter)\(delimiter)" else { continue }

            validTokens.append(canonizedToken)
            processedString = processedString.replacingOccurrences(
                of: canonizedToken,
                with: Strings.processingToken
            )
        }

        return (processedString, validTokens)
    }
}

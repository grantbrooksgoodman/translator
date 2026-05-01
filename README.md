# Translator

A Swift package for translating text between languages using web-based translation platforms.

Translator coordinates between Google Translate, DeepL, and Reverso to produce translations, automatically falling back to alternative platforms when a translation fails or returns an unchanged result. It caches completed translations locally, recognizes input languages to avoid redundant work, and preserves addresses, links, and phone numbers through the translation process.

---

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Installation](#installation)
- [Getting Started](#getting-started)
  - [Prewarm Connections](#prewarm-connections)
  - [Translate a Single String](#translate-a-single-string)
  - [Translate Multiple Strings](#translate-multiple-strings)
  - [Target a Specific Platform](#target-a-specific-platform)
- [Models](#models)
  - [TranslationInput](#translationinput)
  - [LanguagePair](#languagepair)
  - [Translation](#translation)
  - [TranslationError](#translationerror)
- [Customization](#customization)
  - [Custom Translation Caching](#custom-translation-caching)
  - [Custom Logging](#custom-logging)
- [Concurrency](#concurrency)

---

## Overview

| Type | Description |
| --- | --- |
| [`TranslationService`](Sources/Services/Public/TranslationService.swift) | The primary interface for translating text. |
| [`LanguageRecognitionService`](Sources/Services/Public/LanguageRecognitionService.swift) | Evaluates the likelihood that a string belongs to a given language. |
| [`LocalTranslationArchiver`](Sources/Services/Public/LocalTranslationArchiver.swift) | The default on-device cache for completed translations. |
| [`Translator.Config`](Sources/Translator.swift#L26) | The central configuration point for registering custom delegates. |

---

## Requirements

| Platform | Minimum Version |
| --- | --- |
| iOS | 17.0 |

Translator has no external dependencies.

---

## Installation

Translator is distributed as a Swift package. Add it to your project using [Swift Package Manager](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/).

---

## Getting Started

### Prewarm Connections

Reduce the latency of the first translation request by establishing network connections ahead of time. Call `prewarm(_:)` early in your app's lifecycle – for example, in your app delegate's `application(_:didFinishLaunchingWithOptions:)` method:

```swift
@MainActor
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    TranslationService.shared.prewarm()
    return true
}
```

This establishes DNS resolution and TLS sessions to each translation platform without retaining any web views or accumulating cookies. Subsequent translation requests reuse these connections through the shared WebKit networking layer.

To prewarm only specific platforms, pass them explicitly:

```swift
TranslationService.shared.prewarm([.deepL, .google])
```

### Translate a Single String

Use [`TranslationService`](Sources/Services/Public/TranslationService.swift) to translate text between languages. Provide a [`TranslationInput`](Sources/Models/Public/TranslationInput.swift) and a [`LanguagePair`](Sources/Models/Public/LanguagePair.swift), and the service selects the best available platform automatically:

```swift
import Translator

let result = await TranslationService.shared.translate(
    TranslationInput("Good morning"),
    languagePair: LanguagePair(from: "en", to: "fr")
)

switch result {
case let .success(translation):
    print(translation.output)
case let .failure(error):
    print(error.localizedDescription)
}
```

### Translate Multiple Strings

Translate multiple inputs concurrently by calling `getTranslations(_:languagePair:)`. The service processes up to 10 translations concurrently and returns results in the same order as the inputs:

```swift
let inputs: [TranslationInput] = [
    .init("Hello"),
    .init("Goodbye"),
    .init("Thank you"),
]

let result = await TranslationService.shared.getTranslations(
    inputs,
    languagePair: LanguagePair(from: "en", to: "ja")
)
```

If any translation in the batch fails, the entire operation is canceled and the error is returned.

### Target a Specific Platform

To bypass automatic platform selection, specify a [`TranslationPlatform`](Sources/Models/Public/TranslationPlatform.swift) directly:

```swift
let result = await TranslationService.shared.translate(
    TranslationInput("Hello"),
    languagePair: LanguagePair(from: "en", to: "de"),
    platform: .deepL
)
```

The available platforms are `.google`, `.deepL`, and `.reverso`. Not every platform supports every language; if the requested language pair is unsupported, the translation fails with `TranslationError.failedToGenerateRequestURL`.

---

## Models

### TranslationInput

[`TranslationInput`](Sources/Models/Public/TranslationInput.swift) represents the source text for a translation request. It supports an optional `alternate` string that, when provided, takes precedence over the `original` during translation:

```swift
// Simple input
let input = TranslationInput("Hello, world!")

// Input with an alternate
let input = TranslationInput("Hello, world!", alternate: "Hello world")
```

### LanguagePair

A pair of [ISO 639-1](https://www.iso.org/iso-639-language-code) language codes representing the source and target languages:

```swift
let pair = LanguagePair(from: "en", to: "fr")

// Or from a hyphenated string
let pair = LanguagePair("en-fr")
```

Both language codes must be exactly two characters long. Use `isWellFormed` to check validity before use. When the source and target languages are the same, `isIdempotent` returns `true` and the service returns the original input unchanged.

### Translation

A completed translation containing the original `input`, the translated `output`, and the `languagePair`. You receive [`Translation`](Sources/Models/Public/Translation.swift) values from the translation methods on [`TranslationService`](Sources/Services/Public/TranslationService.swift).

### TranslationError

An error that occurs during a translation operation. [`TranslationError`](Sources/Models/Public/TranslationError.swift) conforms to `LocalizedError`, providing a human-readable description for each case:

| Case | Description |
| --- | --- |
| `invalidArguments` | The input or language pair fails validation. |
| `failedToGenerateRequestURL` | The platform does not support the requested language pair. |
| `timedOut` | The translation operation exceeded its time limit. |
| `malformedTranslationResult` | The platform returned an unusable response. |
| `evaluateJavaScriptFailed` | JavaScript evaluation on the platform's web page failed. |
| `javaScriptError` | The platform returned a JavaScript error. |
| `webViewNavigationFailed` | Navigation to the platform's web page failed. |
| `unknown` | An error that does not fall into any other category. |

---

## Customization

### Custom Translation Caching

By default, [`TranslationService`](Sources/Services/Public/TranslationService.swift) caches translations using `LocalTranslationArchiver`, which stores them in `UserDefaults`. To provide a custom caching strategy, create a type that conforms to [`TranslationArchiverDelegate`](Sources/Protocols/Public/TranslationArchiverDelegateProtocol.swift) and register it:

```swift
final class DatabaseArchiver: TranslationArchiverDelegate {
    func addValue(_ translation: Translation) { /* ... */ }
    func addValues(_ translations: Set<Translation>) { /* ... */ }
    func getValue(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    ) -> Translation? { /* ... */ }
    func removeValue(
        inputValueEncodedHash hash: String,
        languagePair: LanguagePair
    ) { /* ... */ }
    func clearArchive() { /* ... */ }
}

Translator.config.registerArchiverDelegate(DatabaseArchiver())
```

Conforming types must be thread-safe. [`TranslationService`](Sources/Services/Public/TranslationService.swift) may invoke archiver methods concurrently from multiple tasks.

### Custom Logging

To receive diagnostic messages from the framework, create a type that conforms to [`TranslationLoggerDelegate`](Sources/Protocols/Public/TranslationLoggerDelegateProtocol.swift) and register it:

```swift
final class TranslationLogger: TranslationLoggerDelegate {
    func log(
        _ text: String,
        sender: Any,
        fileName: String,
        function: String,
        line: Int
    ) {
        print("[\(fileName):\(line)] \(function) – \(text)")
    }
}

Translator.config.registerLoggerDelegate(TranslationLogger())
```

When no logger is registered, diagnostic messages are silently discarded.

---

## Concurrency

Translator adopts Swift 6 strict concurrency. All public types conform to `Sendable`, and the primary interfaces are safe to use from any actor or task context:

- **[`TranslationService`](Sources/Services/Public/TranslationService.swift)** is a `Sendable` structure. Its methods are asynchronous and safe to call from any context.
- **[`LanguageRecognitionService`](Sources/Services/Public/LanguageRecognitionService.swift)** is an actor. Access its methods with `await`.
- **[`LocalTranslationArchiver`](Sources/Services/Public/LocalTranslationArchiver.swift)** uses internal locking and is safe to call from any thread.
- **[`Translator.Config`](Sources/Translator.swift)** uses internal locking. Delegate registration and access are safe from any thread.

---

&copy; NEOTechnica Corporation. All rights reserved.

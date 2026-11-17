//
//  TranslationService+PrewarmExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension TranslationService {
    /// Warms the underlying network connections to translation service hosts.
    ///
    /// Call this method early in the app lifecycle (e.g. at launch) to establish
    /// DNS resolution and TLS sessions ahead of the first translation request.
    /// This also precompiles the content-blocking rules used by the web view
    /// pipeline, reducing latency on the first call to
    /// ``translate(_:languagePair:)`` without retaining any web views.
    /// Web activity is confined to a private, memory-backed data
    /// store, so prewarming leaves your app's cookies and website data
    /// untouched.
    ///
    /// ```swift
    /// TranslationService.shared.prewarm()
    /// ```
    ///
    /// - Parameter platforms: The platforms to prewarm connections for.
    ///   Defaults to ``TranslationPlatform/allCases``.
    @MainActor
    func prewarm(
        _ platforms: [TranslationPlatform] = TranslationPlatform.allCases
    ) {
        BaseTranslator.prewarm(platforms)

        // Decode and index the local archive ahead of the first lookup.
        if Translator.config.archiverDelegate == nil {
            LocalTranslationArchiver.shared.preload()
        }
    }
}

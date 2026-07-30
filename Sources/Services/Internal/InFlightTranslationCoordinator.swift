//
//  InFlightTranslationCoordinator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// Deduplicates concurrent translation requests: while a translation for a
/// given input and language pair is in flight, subsequent requests for the
/// same work await the existing task instead of starting their own.
actor InFlightTranslationCoordinator {
    // MARK: - Properties

    static let shared = InFlightTranslationCoordinator()

    private var inFlightTasks = [String: Task<Translation, any Error>]()

    // MARK: - Init

    private init() {}

    // MARK: - Task Coordination

    func task(
        forKey key: String,
        operation: @escaping @Sendable () async throws -> Translation
    ) -> Task<Translation, any Error> {
        if let inFlightTask = inFlightTasks[key] { return inFlightTask }

        let translationTask = Task { try await operation() }
        inFlightTasks[key] = translationTask

        Task {
            _ = try? await translationTask.value
            clearTask(forKey: key)
        }

        return translationTask
    }

    // MARK: - Auxiliary

    private func clearTask(forKey key: String) {
        inFlightTasks[key] = nil
    }
}

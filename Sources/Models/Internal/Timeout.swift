//
//  Timeout.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

@MainActor
final class Timeout {
    // MARK: - Properties

    private var callback: (() -> Void)?
    private var isValid = true

    // MARK: - Object Lifecycle

    init(
        after duration: Duration,
        callback: @escaping () -> Void
    ) {
        self.callback = callback
        Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard let self,
                  self.isValid else { return }
            self.invoke()
        }
    }

    // MARK: - Cancellation

    func cancel() {
        callback = nil
        isValid = false
    }

    // MARK: - Auxiliary

    private func invoke() {
        callback?()
        cancel()
    }
}

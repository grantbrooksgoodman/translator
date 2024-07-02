//
//  Timeout.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

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
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(duration.milliseconds))) {
            guard self.isValid else { return }
            self.invoke()
        }
    }

    deinit {
        cancel()
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

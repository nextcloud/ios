// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public actor NCDebouncer {
    private let delay: Duration
    private let maxEventCount: Int
    private var eventCount = 0
    private var pendingTask: Task<Void, Never>?
    private var latestBlock: (@MainActor @Sendable () async -> Void)?

    public init(delay: Duration = .seconds(2), maxEventCount: Int) {
        self.delay = delay
        self.maxEventCount = maxEventCount
    }

    public func call(_ block: @MainActor @Sendable @escaping () async -> Void, immediate: Bool = false) {
        latestBlock = block

        if immediate {
            commit()
            return
        }

        eventCount += 1
        scheduleIfNeeded()

        if eventCount >= maxEventCount {
            commit()
        }
    }

    public func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
        latestBlock = nil
        eventCount = 0
    }

    private func scheduleIfNeeded() {
        guard pendingTask == nil else { return }
        pendingTask = Task { [weak self] in
            guard let delay = self?.delay else { return }
            try? await Task.sleep(for: delay)
            await self?.commit()
        }
    }

    private func commit() {
        pendingTask?.cancel()
        pendingTask = nil
        eventCount = 0

        if let block = latestBlock {
            latestBlock = nil
            Task { @MainActor in
                await block()
            }
        }
    }
}

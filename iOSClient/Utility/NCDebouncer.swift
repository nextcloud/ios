// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public actor NCDebouncer {
    private let delay: Duration
    private let maxEventCount: Int
    private var eventCount: Int = 0
    private var pendingTask: Task<Void, Never>?
    private var latestBlock: (@MainActor @Sendable () async -> Void)?
    private var isPaused: Bool = false

    // MARK: - Init

    public init(delay: Duration = .seconds(2), maxEventCount: Int) {
        self.delay = delay
        self.maxEventCount = maxEventCount
    }

    // MARK: - Public API

    public func call(_ block: @MainActor @Sendable @escaping () async -> Void, immediate: Bool = false) {
        latestBlock = block

        guard !isPaused else {
            // We only store the latest block and count events,
            // but we never schedule or commit while paused.
            eventCount += 1
            return
        }

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

    public func pause() {
        guard !isPaused else {
            return
        }

        isPaused = true
        pendingTask?.cancel()
        pendingTask = nil
    }

    public func isPausedNow() -> Bool {
        return isPaused
    }

    public func resume() {
        guard isPaused else {
            return
        }

        isPaused = false

        // If something accumulated while paused, commit immediately.
        if latestBlock != nil {
            commit()
        }
    }

    public func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
        latestBlock = nil
        eventCount = 0
    }

    // MARK: - Internal

    private func scheduleIfNeeded() {
        guard pendingTask == nil, !isPaused else {
            return
        }

        pendingTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.delay)
            await self.commit()
        }
    }

    private func commit() {
        guard !isPaused else {
            return
        }

        pendingTask?.cancel()
        pendingTask = nil
        eventCount = 0

        guard let block = latestBlock else {
            return
        }
        latestBlock = nil

        Task { @MainActor in
            await block()
        }
    }
}

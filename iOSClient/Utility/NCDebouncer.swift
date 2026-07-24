// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public actor NCDebouncer {
    private let delay: Duration
    private let maxEventCount: Int
    private var eventCount: Int = 0
    private var pendingTask: Task<Void, Never>?
    private var executionTask: Task<Void, Never>?
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

    public func resume() {
        guard isPaused else {
            return
        }

        isPaused = false

        if latestBlock != nil {
            commit()
        }
    }

    public func cancel() {
        pendingTask?.cancel()
        pendingTask = nil

        executionTask?.cancel()
        executionTask = nil

        latestBlock = nil
        eventCount = 0
    }

    public func isPausedNow() -> Bool {
        isPaused
    }

    // MARK: - Internal

    private func scheduleIfNeeded() {
        guard pendingTask == nil,
              !isPaused else {
            return
        }

        pendingTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await Task.sleep(for: self.delay)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

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

        guard executionTask == nil,
              let block = latestBlock else {
            return
        }

        latestBlock = nil

        executionTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled else {
                await self?.executionDidFinish()
                return
            }

            await block()
            await self?.executionDidFinish()
        }
    }

    private func executionDidFinish() {
        executionTask = nil

        guard !isPaused,
              latestBlock != nil else {
            return
        }

        commit()
    }
}

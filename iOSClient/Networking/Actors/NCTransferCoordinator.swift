// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Alamofire

/// Defines the scheduling priority for shared transfer requests.
public enum NCTransferCoordinatorPriority: Int, Sendable {
    case background = 0
    case prefetch = 1
    case visible = 2
    case userInitiated = 3
}

/// Coordinates shared transfers with bounded concurrency, priority scheduling,
/// and automatic removal of requests cancelled while waiting in the queue.
public actor NCTransferCoordinator {
    static let shared = NCTransferCoordinator()

    private struct PendingRequest {
        let identifier: UUID
        let priority: NCTransferCoordinatorPriority
        let sequence: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private var activeTransfers = 0
    private var pendingRequests: [PendingRequest] = []
    private var nextSequence: UInt64 = 0

    private struct ManagedTask {
        let token: UUID
        let task: Task<Void, Never>
    }

    private var tasks: [String: ManagedTask] = [:]

    /// Starts a cancellable transfer associated with a stable caller-defined identifier.
    /// Starting another transfer with the same identifier cancels the previous one.
    ///
    /// - Parameters:
    ///   - identifier: A stable identifier used to replace or cancel the transfer.
    ///   - priority: The scheduling priority of the transfer.
    ///   - operation: The asynchronous transfer work to execute after a slot is acquired.
    func start(
        identifier: String,
        priority: NCTransferCoordinatorPriority,
        operation: @escaping @Sendable () async throws -> Void
    ) {
        cancel(identifier: identifier)

        let token = UUID()
        let task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.perform(priority: priority, operation: operation)
            } catch is CancellationError {
                // The transfer was cancelled before completion.
            } catch {
                // The caller owns transfer-specific error handling inside operation.
            }

            await self.removeTask(identifier: identifier, token: token)
        }

        tasks[identifier] = ManagedTask(token: token, task: task)
    }

    /// Cancels the transfer associated with the specified identifier.
    ///
    /// - Parameter identifier: The stable identifier assigned when the transfer was started.
    func cancel(identifier: String) {
        guard let managedTask = tasks.removeValue(forKey: identifier) else {
            return
        }

        managedTask.task.cancel()
    }

    /// Cancels every managed transfer currently registered by the coordinator.
    func cancelAll() {
        let managedTasks = tasks.values
        tasks.removeAll()

        for managedTask in managedTasks {
            managedTask.task.cancel()
        }
    }

    /// Executes transfer work after acquiring a shared transfer slot.
    ///
    /// - Parameters:
    ///   - priority: The scheduling priority of the requesting consumer.
    ///   - operation: The asynchronous transfer work to execute.
    /// - Returns: The value returned by the operation.
    func perform<T: Sendable>(
        priority: NCTransferCoordinatorPriority,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await acquire(priority: priority)
        defer {
            release()
        }

        try Task.checkCancellation()
        return try await operation()
    }

    /// Removes a completed task only when it is still the latest task for the identifier.
    ///
    /// - Parameters:
    ///   - identifier: The stable identifier assigned when the transfer was started.
    ///   - token: The unique token assigned to that specific task instance.
    private func removeTask(identifier: String, token: UUID) {
        guard tasks[identifier]?.token == token else {
            return
        }

        tasks.removeValue(forKey: identifier)
    }

    /// Waits until a shared transfer slot is available.
    ///
    /// - Parameter priority: The scheduling priority of the requesting consumer.
    func acquire(priority: NCTransferCoordinatorPriority) async throws {
        try Task.checkCancellation()

        guard activeTransfers >= maximumConcurrentTransfers else {
            activeTransfers += 1
            return
        }

        let identifier = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                nextSequence &+= 1

                pendingRequests.append(
                    PendingRequest(
                        identifier: identifier,
                        priority: priority,
                        sequence: nextSequence,
                        continuation: continuation
                    )
                )

                pendingRequests.sort {
                    if $0.priority.rawValue != $1.priority.rawValue {
                        return $0.priority.rawValue > $1.priority.rawValue
                    }

                    return $0.sequence < $1.sequence
                }
            }
        } onCancel: {
            Task {
                await self.cancelPendingRequest(identifier: identifier)
            }
        }
    }

    /// Releases a previously acquired transfer slot.
    func release() {
        guard !pendingRequests.isEmpty else {
            activeTransfers = max(0, activeTransfers - 1)
            return
        }

        let request = pendingRequests.removeFirst()
        request.continuation.resume()
    }

    /// Removes a waiting request and resumes it with cancellation.
    ///
    /// - Parameter identifier: The identifier assigned to the pending request.
    private func cancelPendingRequest(identifier: UUID) {
        guard let index = pendingRequests.firstIndex(where: { $0.identifier == identifier }) else {
            return
        }

        let request = pendingRequests.remove(at: index)
        request.continuation.resume(throwing: CancellationError())
    }

    private var maximumConcurrentTransfers: Int {
        max(1, NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload)
    }
}

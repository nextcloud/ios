// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Alamofire

/// A thread-safe registry for tracking in-flight `URLSessionTask` instances.
///
/// Each task is associated with a string identifier (`identifier`) that you define,
/// allowing you to check whether a request is already running, avoid duplicates,
/// and cancel all active tasks at once. The registry automatically removes
/// completed tasks via `cleanupCompleted()` to keep memory usage compact.
///
/// Typical use cases:
/// - Ensure only one task per identifier is active at a time.
/// - Query whether a specific request is still running (`isReading`).
/// - Forcefully stop a specific request (`cancel`).
/// - Forcefully stop all tasks when leaving a screen (`cancelAll`).
actor NetworkingTasks {
    private var active: [(identifier: String, task: URLSessionTask)] = []

    /// Returns whether there is an in-flight task for the given URL.
    ///
    /// A task is considered in-flight if its `state` is `.running` or `.suspended`.
    /// - Parameter identifier: The identifier to check.
    /// - Returns: `true` if a matching in-flight task exists; otherwise `false`.
    func isReading(identifier: String) -> Bool {
        // Drop finished/canceling tasks globally
        cleanup()

        return active.contains {
            $0.identifier == identifier && ($0.task.state == .running || $0.task.state == .suspended)
        }
    }

    /// Tracks a newly created `URLSessionTask` for the given identifier.
    ///
    /// If a running entry for the same identifier exists, it is removed before appending the new one.
    /// - Parameters:
    ///   - identifier: The identifier associated with the task.
    ///   - task: The `URLSessionTask` to track.
    func track(identifier: String, task: URLSessionTask) {
        // Drop finished/canceling tasks globally
        cleanup()

        active.removeAll {
            $0.identifier == identifier && $0.task.state == .running
        }
        active.append((identifier, task))
        nkLog(tag: NCGlobal.shared.logTagNetworkingTasks, emoji: .start, message: "Start task for identifier: \(identifier)", consoleOnly: true)
    }

    /// create a Identifier
    ///
    func createIdentifier(account: String? = nil, path: String? = nil, name: String) -> String {
        if let account,
           let path {
            return account + "_" + path + "_" + name
        } else if let path {
            return path + "_" + name
        } else {
            return name
        }
    }

    /// Cancels and removes all tasks associated with the given id.
    ///
    /// - Parameter identifier: The identifier whose tasks should be canceled.
    func cancel(identifier: String) {
        // Drop finished/canceling tasks globally
        cleanup()

        for element in active where element.identifier == identifier {
            element.task.cancel()
            nkLog(tag: NCGlobal.shared.logTagNetworkingTasks, emoji: .cancel, message: "Cancel task for identifier: \(identifier)", consoleOnly: true)
        }
        active.removeAll {
            $0.identifier == identifier
        }
    }

    /// Cancels all tracked `URLSessionTask` and clears the registry.
    ///
    /// Call this when leaving the page/screen or when the operation must be forcefully stopped.
    func cancelAll() {
        active.forEach {
            $0.task.cancel()
            nkLog(tag: NCGlobal.shared.logTagNetworkingTasks, emoji: .cancel, message: "Cancel task with identifier: \($0.identifier)", consoleOnly: true)
        }
        active.removeAll()
    }

    /// Removes tasks that have completed from the registry.
    ///
    /// Useful to keep the in-memory list compact during long-running operations.
    func cleanup() {
        active.removeAll {
            $0.task.state == .completed || $0.task.state == .canceling
        }
    }
}

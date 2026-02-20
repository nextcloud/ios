// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Alamofire

/// Actor-based dispatcher that manages weak NCTransferDelegate references
/// and delivers notifications safely across concurrency domains.
actor NCTransferDelegateDispatcher {
    // Weak reference collection of delegates
    private var transferDelegates = NSHashTable<AnyObject>.weakObjects()

    /// Adds a delegate safely.
    func addDelegate(_ delegate: NCTransferDelegate) {
        if transferDelegates.contains(delegate) {
            return
        }
        transferDelegates.add(delegate)
    }

    /// Remove a delegate safely.
    func removeDelegate(_ delegate: NCTransferDelegate) {
        transferDelegates.remove(delegate)
    }

    /// Returns a strong snapshot of all valid delegates.
    private func snapshotDelegates() -> [NCTransferDelegate] {
        transferDelegates.allObjects.compactMap { $0 as? NCTransferDelegate }
    }

    /// Notifies all delegates on the main actor.
    func notifyAllDelegates(_ block: @MainActor @escaping (NCTransferDelegate) -> Void) async {
        let delegates = snapshotDelegates()
        await MainActor.run {
            for delegate in delegates {
                block(delegate)
            }
        }
    }

    /// Notifies only the delegate matching a specific scene identifier.
    func notifyDelegate(forScene sceneIdentifier: String, _ block: @MainActor @escaping (NCTransferDelegate) -> Void) async {
        let delegates = snapshotDelegates()
        await MainActor.run {
            for delegate in delegates where delegate.sceneIdentifier == sceneIdentifier {
                block(delegate)
            }
        }
    }

    /// Notifies matching and non-matching delegates on the main actor.
    func notifyDelegates(forScene sceneIdentifier: String, matching: @MainActor @escaping (NCTransferDelegate) -> Void, others: @MainActor @escaping (NCTransferDelegate) -> Void) async {
        let delegates = snapshotDelegates()
        await MainActor.run {
            for delegate in delegates {
                if delegate.sceneIdentifier == sceneIdentifier {
                    matching(delegate)
                } else {
                    others(delegate)
                }
            }
        }
    }

    /// Notifies all delegates concurrently using async/await.
    func notifyAllDelegatesAsync(_ block: @escaping @Sendable (NCTransferDelegate) async -> Void) async {
        let delegates = snapshotDelegates()
        await withTaskGroup(of: Void.self) { group in
            for delegate in delegates {
                group.addTask {
                    await block(delegate)
                }
            }
        }
    }
}

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

/// Quantizes per-task progress updates to integer percentages (0...100).
/// Each (serverUrlFileName) pair is tracked separately, so you get
/// at most one update per integer percent for each transfer.
actor ProgressQuantizer {
    private var lastPercent: [String: Int] = [:]

    /// Returns `true` only when integer percent changes (or hits 100).
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The name of the file being transferred.
    ///   - fraction: Progress fraction [0.0 ... 1.0].
    func shouldEmit(serverUrlFileName: String, fraction: Double) -> Bool {
        let percent = min(max(Int((fraction * 100).rounded(.down)), 0), 100)

        let last = lastPercent[serverUrlFileName] ?? -1
        guard percent != last || percent == 100 else {
            return false
        }

        lastPercent[serverUrlFileName] = percent
        return true
    }

    /// Clears stored state for a finished transfer.
    func clear(serverUrlFileName: String) {
        lastPercent.removeValue(forKey: serverUrlFileName)
    }
}

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

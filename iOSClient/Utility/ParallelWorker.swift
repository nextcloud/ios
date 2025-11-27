// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

/// Object to execute multiple tasks in parallel like uploading or downloading.
/// - Can display a progress indicator with status message
/// - Can be canceled by user
class ParallelWorker {
    let completionGroup = DispatchGroup()
    let queue = DispatchQueue(label: "ParallelWorker")
    let semaphore: DispatchSemaphore
    var completedTasks = 0
    var isCancelled = false

    /// Creates a ParallelWorker
    /// - Parameters:
    ///   - n: Amount of tasks to be executed in parallel
    init(n: Int) {
        semaphore = DispatchSemaphore(value: n)
    }

    /// Execute
    /// - Parameter task: The task to execute. Needs to call `completion()` when done so the next task can be executed.
    func execute(task: @escaping (_ completion: @escaping () -> Void) -> Void) {
        completionGroup.enter()
        queue.async {
            self.semaphore.wait()
            guard !self.isCancelled else { return self.completionGroup.leave() }
            task {
                self.completedTasks += 1
                self.semaphore.signal()
                self.completionGroup.leave()
            }
        }
    }

    /// Indicates that all tasks have been scheduled. Some tasks might still be in progress.
    /// - Parameter completion: Will be called after all tasks have finished
    func completeWork(completion: (() -> Void)? = nil) {
        completionGroup.notify(queue: .main) {
            guard !self.isCancelled else { return }
            completion?()
        }
    }
}

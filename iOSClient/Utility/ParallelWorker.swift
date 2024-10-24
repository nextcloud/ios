//
//  ParallelWorker.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.02.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit

/// Object to execute multiple tasks in parallel like uploading or downloading.
/// - Can display a progress indicator with status message
/// - Can be canceled by user
class ParallelWorker {
    let completionGroup = DispatchGroup()
    let queue = DispatchQueue(label: "ParallelWorker")
    let semaphore: DispatchSemaphore
    let titleKey: String
    var hud = NCHud()
    var totalTasks: Int?
    var completedTasks = 0
    var isCancelled = false

    /// Creates a ParallelWorker
    /// - Parameters:
    ///   - n: Amount of tasks to be executed in parallel
    ///   - titleKey: Localized String key, used for the status. Default: *Please Wait...*
    ///   - totalTasks: Number of total tasks, if known
    ///   - hudView: The parent view or current view which should present the progress indicator. If `nil`, no progress indicator will be shown.
    init(n: Int, titleKey: String?, totalTasks: Int?, controller: NCMainTabBarController?) {
        semaphore = DispatchSemaphore(value: n)
        self.totalTasks = totalTasks
        self.titleKey = titleKey ?? "_wait_"

        hud.initHudRing(view: controller?.view,
                        text: NSLocalizedString(self.titleKey, comment: ""),
                        tapToCancelDetailText: true) {
            self.isCancelled = true
            NCNetworking.shared.cancelUploadTasks()
            NCNetworking.shared.cancelDownloadTasks()
        }
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
                self.hud.setText(text: "\(NSLocalizedString(self.titleKey, comment: ""))")
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
            self.hud.dismiss()
            completion?()
        }
    }
}

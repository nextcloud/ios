// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import SwiftUI

class NCAssistantModel: ObservableObject {
    @Published var types: [TaskTypeData] = []
    @Published var filteredTasks: [AssistantTask] = []
    @Published var selectedType: TaskTypeData?
    @Published var selectedTask: AssistantTask?

    @Published var hasError: Bool = false
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var controller: NCMainTabBarController?

    private var tasks: [AssistantTask] = []

    private let session: NCSession.Session

    private let useV2: Bool

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        session = NCSession.shared.getSession(controller: controller)
        useV2 = NCCapabilities.shared.getCapabilities(account: session.account).capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion30
        //        useV2 = false
        loadAllTypes()
    }

    func refresh() {
        isRefreshing = true
        loadAllTasks(type: selectedType)
    }

    func filterTasks(ofType type: TaskTypeData?) {
        if let type {
            self.filteredTasks = tasks.filter({ $0.type == type.id })
        } else {
            self.filteredTasks = tasks
        }

        self.filteredTasks = filteredTasks.sorted(by: { $0.completionExpectedAt ?? 0 > $1.completionExpectedAt ?? 0 })
    }

    func selectTaskType(_ type: TaskTypeData?) {
        selectedType = type

        filteredTasks.removeAll()
        loadAllTasks(type: type)
    }

    func selectTask(_ task: AssistantTask) {
        selectedTask = task
        isLoading = true

        if useV2 {
            NextcloudKit.shared.textProcessingGetTasksV2(taskType: task.type ?? "", account: session.account, completion: { _, _, _, error in
                handle(task: task, error: error)
            })
        } else {
            NextcloudKit.shared.textProcessingGetTask(taskId: Int(task.id), account: session.account) { _, task, _, error in
                guard let task else { return }
                let taskV2 = NKTextProcessingTask.toV2(tasks: [task]).tasks.first
                handle(task: taskV2, error: error)
            }
        }

        func handle(task: AssistantTask?, error: NKError?) {
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            self.selectedTask = task
        }
    }

    func scheduleTask(input: String) {
        isLoading = true

        if useV2 {
            guard let selectedType else { return }
            NextcloudKit.shared.textProcessingScheduleV2(input: input, taskType: selectedType, account: session.account) { _, task, _, error in
                handle(task: task, error: error)
            }
        } else {
            NextcloudKit.shared.textProcessingSchedule(input: input, typeId: selectedType?.id ?? "", identifier: "assistant", account: session.account) { _, task, _, error in
                guard let task, let taskV2 = NKTextProcessingTask.toV2(tasks: [task]).tasks.first else { return }
                handle(task: taskV2, error: error)
            }
        }

        func handle(task: AssistantTask?, error: NKError?) {
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            guard let task else { return }

            self.tasks.insert(task, at: 0)
            self.filteredTasks.insert(task, at: 0)
        }
    }

    func deleteTask(_ task: AssistantTask) {
        isLoading = true

        if useV2 {
            NextcloudKit.shared.textProcessingDeleteTaskV2(taskId: task.id, account: session.account) { _, _, error in
                handle(task: task, error: error)
            }
        } else {
            NextcloudKit.shared.textProcessingDeleteTask(taskId: Int(task.id), account: session.account) { _, _, _, error in
                handle(task: task, error: error)
            }
        }

        func handle(task: AssistantTask, error: NKError?) {
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            self.tasks.removeAll(where: { $0.id == task.id })
            self.filteredTasks.removeAll(where: { $0.id == task.id })
        }
    }

    func shareTask(_ task: AssistantTask) {
        let activityVC = UIActivityViewController(activityItems: [(task.input?.input ?? "") + "\n\n" + (task.output?.output ?? "")], applicationActivities: nil)
        controller?.presentedViewController?.present(activityVC, animated: true, completion: nil) // presentedViewController = the UIHostingController presenting the Assistant
    }

    private func loadAllTypes() {
        isLoading = true

        if useV2 {
            NextcloudKit.shared.textProcessingGetTypesV2(account: session.account) { _, types, _, error in
                handle(types: types, error: error)
            }
        } else {
            NextcloudKit.shared.textProcessingGetTypes(account: session.account) { _, types, _, error in
                guard let types else { return }
                let typesV2 = NKTextProcessingTaskType.toV2(type: types).types

                handle(types: typesV2, error: error)
            }
        }

        func handle(types: [TaskTypeData]?, error: NKError) {
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            guard let types else { return }

            self.types = types

            if self.selectedType == nil {
                self.selectTaskType(types.first)
            }

            self.loadAllTasks(type: selectedType)
        }
    }

    private func loadAllTasks(appId: String = "assistant", type: TaskTypeData?) {
        isLoading = true

        if useV2 {
            NextcloudKit.shared.textProcessingGetTasksV2(taskType: type?.id ?? "", account: session.account) { _, tasks, _, error in
                guard let tasks = tasks?.tasks.filter({ $0.appId == "assistant" }) else { return }
                handle(tasks: tasks, error: error)
            }
        } else {
            NextcloudKit.shared.textProcessingTaskList(appId: appId, account: session.account) { _, tasks, _, error in
                guard let tasks else { return }
                handle(tasks: NKTextProcessingTask.toV2(tasks: tasks).tasks, error: error)
            }
        }

        func handle(tasks: [AssistantTask], error: NKError?) {
            isLoading = false
            isRefreshing = false

            if error != .success {
                self.hasError = true
                return
            }

            self.tasks = tasks
            self.filterTasks(ofType: self.selectedType)
        }
    }
}

extension NCAssistantModel {
    public func loadDummyData() {
        let loremIpsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

        var tasks: [AssistantTask] = []

        for _ in 1...10 {
            tasks.append(AssistantTask(id: 1, type: "", status: "", userId: "", appId: "", input: .init(input: loremIpsum), output: .init(output: loremIpsum), completionExpectedAt: 1712666412, progress: nil, lastUpdated: nil, scheduledAt: nil, endedAt: nil))
        }

        self.types = [
            TaskTypeData(id: "1", name: "Free Prompt", description: "", inputShape: nil, outputShape: nil),
            TaskTypeData(id: "2", name: "Summarize", description: "", inputShape: nil, outputShape: nil),
            TaskTypeData(id: "3", name: "Generate headline", description: "", inputShape: nil, outputShape: nil),
            TaskTypeData(id: "4", name: "Reformulate", description: "", inputShape: nil, outputShape: nil)
        ]

        self.tasks = tasks
        self.filteredTasks = tasks
        self.selectedType = types[0]
        self.selectedTask = filteredTasks[0]
    }
}

extension AssistantTask {
    struct StatusInfo {
        let stringKey, imageSystemName: String
    }

    var statusInfo: StatusInfo {
        return switch status {
        case "0", "STATUS_UNKNOWN": StatusInfo(stringKey: "_assistant_task_unknown_", imageSystemName: "questionmark.circle")
        case "1", "STATUS_SCHEDULED": StatusInfo(stringKey: "_assistant_task_scheduled_", imageSystemName: "clock.badge")
        case "2", "STATUS_RUNNING": StatusInfo(stringKey: "_assistant_task_in_progress_", imageSystemName: "arrow.2.circlepath")
        case "3", "STATUS_SUCCESSFUL": StatusInfo(stringKey: "_assistant_task_completed_", imageSystemName: "checkmark.circle")
        case "4", "STATUS_FAILED": StatusInfo(stringKey: "_assistant_task_failed_", imageSystemName: "exclamationmark.circle")
        default: StatusInfo(stringKey: "_assistant_task_unknown_", imageSystemName: "questionmark.circle")
        }
    }

    var statusDate: String {
        return NCUtility().getRelativeDateTitle(.init(timeIntervalSince1970: TimeInterval((lastUpdated ?? completionExpectedAt) ?? 0)))
    }
}

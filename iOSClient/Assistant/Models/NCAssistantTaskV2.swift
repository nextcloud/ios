//
//  NCAssistantModel.swift
//  Nextcloud
//
//  Created by Milen on 08.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import NextcloudKit
import SwiftUI

class NCAssistantTaskV2: ObservableObject {
//    @Published var types: [NKTextProcessingTaskType] = []
//    @Published var filteredTasks: [NKTextProcessingTask] = []
//    @Published var selectedType: NKTextProcessingTaskType?
//    @Published var selectedTask: NKTextProcessingTask?

    let useV2 = true

    @Published var types: [TaskTypeData] = []
    @Published var filteredTasks: [AssistantTask] = []
    @Published var selectedType: TaskTypeData?
    @Published var selectedTask: AssistantTask?

    @Published var hasError: Bool = false
    @Published var isLoading: Bool = false
    @Published var controller: NCMainTabBarController?

    private var tasks: [AssistantTask] = []

//    private let excludedTypeIds = ["OCA\\ContextChat\\TextProcessing\\ContextChatTaskType"]
    private var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        load()
    }

    func load() {
        loadAllTypes()
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
        filterTasks(ofType: self.selectedType)
    }

    func selectTask(_ task: AssistantTask) {
        selectedTask = task
//        guard let id = task.id else { return }
        isLoading = true

        NextcloudKit.shared.textProcessingGetTasksV2(taskType: task.type ?? "", account: session.account, completion: { account, tasks, responseData, error in
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            self.selectedTask = task
        })
    }

    func scheduleTask(input: String) {
        isLoading = true

        NextcloudKit.shared.textProcessingScheduleV2(input: input, taskType: selectedType!, account: session.account, completion: { account, task, responseData, error in
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            guard let task else { return }

            withAnimation {
                self.tasks.insert(task, at: 0)
                self.filteredTasks.insert(task, at: 0)
            }
        })
       
    }

    func deleteTask(_ task: AssistantTask) {
        isLoading = true

        NextcloudKit.shared.textProcessingDeleteTaskV2(taskId: task.id, account: session.account) { account, responseData, error in

            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            withAnimation {
                self.tasks.removeAll(where: { $0.id == task.id })
                self.filteredTasks.removeAll(where: { $0.id == task.id })
            }

        }
    }

    private func loadAllTypes() {
        isLoading = true

        NextcloudKit.shared.textProcessingGetTypesV2(account: session.account) { account, types, responseData, error in
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

//            guard let filteredTypes = types?.types.filter({ !self.excludedTypeIds.contains($0.id)}), !filteredTypes.isEmpty else { return }

            withAnimation {
                self.types = types ?? []
            }

            if self.selectedType == nil {
                self.selectTaskType(types?.first)
            }

            self.loadAllTasks()
        }
    }

    private func loadAllTasks(appId: String = "assistant") {
        isLoading = true

        NextcloudKit.shared.textProcessingGetTasksV2(taskType: "core:text2text", account: session.account) { account, tasks, responseData, error in
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            guard let tasks = tasks else { return }
            self.tasks = tasks.tasks
            self.filterTasks(ofType: self.selectedType)
        }
    }
}

//extension NCAssistantTaskV2 {
//    public func loadDummyData() {
//        let loremIpsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
//
//        var tasks: [NKTextProcessingTask] = []
//
//        for index in 1...10 {
//            tasks.append(NKTextProcessingTask(id: index, type: "OCP\\TextProcessing\\FreePromptTaskType", status: index, userId: "christine", appId: "assistant", input: loremIpsum, output: loremIpsum, identifier: "", completionExpectedAt: 1712666412))
//        }
//
//        self.types = [
//            NKTextProcessingTaskType(id: "1", name: "Free Prompt", description: ""),
//            NKTextProcessingTaskType(id: "2", name: "Summarize", description: ""),
//            NKTextProcessingTaskType(id: "3", name: "Generate headline", description: ""),
//            NKTextProcessingTaskType(id: "4", name: "Reformulate", description: "")
//        ]
//        self.tasks = tasks
//        self.filteredTasks = tasks
//        self.selectedType = types[0]
//        self.selectedTask = filteredTasks[0]
//
//    }
//}
//
//extension NKTextProcessingTask {
//    struct StatusInfo {
//        let stringKey, imageSystemName: String
//    }
//
//    var statusInfo: StatusInfo {
//        return switch status {
//        case 1: StatusInfo(stringKey: "_assistant_task_scheduled_", imageSystemName: "clock")
//        case 2: StatusInfo(stringKey: "_assistant_task_in_progress_", imageSystemName: "clock.badge")
//        case 3: StatusInfo(stringKey: "_assistant_task_completed_", imageSystemName: "checkmark.circle")
//        case 4: StatusInfo(stringKey: "_assistant_task_failed_", imageSystemName: "exclamationmark.circle")
//        default: StatusInfo(stringKey: "_assistant_task_unknown_", imageSystemName: "questionmark.circle")
//        }
//    }
//}

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

class NCAssistantTask: ObservableObject {
    @Published var types: [NKTextProcessingTaskType] = []
    @Published var filteredTasks: [NKTextProcessingTask] = []
    @Published var selectedType: NKTextProcessingTaskType?
    @Published var selectedTask: NKTextProcessingTask?
    @Published var hasError: Bool = false
    @Published var isLoading: Bool = false
    @Published var controller: NCMainTabBarController?

    private var tasks: [NKTextProcessingTask] = []
    private let excludedTypeIds = ["OCA\\ContextChat\\TextProcessing\\ContextChatTaskType"]
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

    func filterTasks(ofType type: NKTextProcessingTaskType?) {
        if let type {
            self.filteredTasks = tasks.filter({ $0.type == type.id })
        } else {
            self.filteredTasks = tasks
        }

        self.filteredTasks = filteredTasks.sorted(by: { $0.completionExpectedAt ?? 0 > $1.completionExpectedAt ?? 0 })
    }

    func selectTaskType(_ type: NKTextProcessingTaskType?) {
        selectedType = type
        filterTasks(ofType: self.selectedType)
    }

    func selectTask(_ task: NKTextProcessingTask) {
        selectedTask = task
        guard let id = task.id else { return }
        isLoading = true

        NextcloudKit.shared.textProcessingGetTask(taskId: id, account: session.account) { _, task, _, error in
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

        NextcloudKit.shared.textProcessingSchedule(input: input, typeId: selectedType?.id ?? "", identifier: "assistant", account: session.account) { _, task, _, error in
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
        }
    }

    func deleteTask(_ task: NKTextProcessingTask) {
        guard let id = task.id else { return }
        isLoading = true

        NextcloudKit.shared.textProcessingDeleteTask(taskId: id, account: session.account) { _, task, _, error in
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            withAnimation {
                self.tasks.removeAll(where: { $0.id == task?.id })
                self.filteredTasks.removeAll(where: { $0.id == task?.id })
            }

        }
    }

    private func loadAllTypes() {
        isLoading = true

        NextcloudKit.shared.textProcessingGetTypes(account: session.account) { _, types, _, error in
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            guard let filteredTypes = types?.filter({ !self.excludedTypeIds.contains($0.id ?? "")}), !filteredTypes.isEmpty else { return }

            withAnimation {
                self.types = filteredTypes
            }

            if self.selectedType == nil {
                self.selectTaskType(filteredTypes.first)
            }

            self.loadAllTasks()
        }
    }

    private func loadAllTasks(appId: String = "assistant") {
        isLoading = true

        NextcloudKit.shared.textProcessingTaskList(appId: appId, account: session.account) { _, tasks, _, error in
            self.isLoading = false

            if error != .success {
                self.hasError = true
                return
            }

            guard let tasks = tasks else { return }
            self.tasks = tasks
            self.filterTasks(ofType: self.selectedType)
        }
    }
}

extension NCAssistantTask {
    public func loadDummyData() {
        let loremIpsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

        var tasks: [NKTextProcessingTask] = []

        for index in 1...10 {
            tasks.append(NKTextProcessingTask(id: index, type: "OCP\\TextProcessing\\FreePromptTaskType", status: index, userId: "christine", appId: "assistant", input: loremIpsum, output: loremIpsum, identifier: "", completionExpectedAt: 1712666412))
        }

        self.types = [
            NKTextProcessingTaskType(id: "1", name: "Free Prompt", description: ""),
            NKTextProcessingTaskType(id: "2", name: "Summarize", description: ""),
            NKTextProcessingTaskType(id: "3", name: "Generate headline", description: ""),
            NKTextProcessingTaskType(id: "4", name: "Reformulate", description: "")
        ]
        self.tasks = tasks
        self.filteredTasks = tasks
        self.selectedType = types[0]
        self.selectedTask = filteredTasks[0]

    }
}

extension NKTextProcessingTask {
    struct StatusInfo {
        let stringKey, imageSystemName: String
    }

    var statusInfo: StatusInfo {
        return switch status {
        case 1: StatusInfo(stringKey: "_assistant_task_scheduled_", imageSystemName: "clock")
        case 2: StatusInfo(stringKey: "_assistant_task_in_progress_", imageSystemName: "clock.badge")
        case 3: StatusInfo(stringKey: "_assistant_task_completed_", imageSystemName: "checkmark.circle")
        case 4: StatusInfo(stringKey: "_assistant_task_failed_", imageSystemName: "exclamationmark.circle")
        default: StatusInfo(stringKey: "_assistant_task_unknown_", imageSystemName: "questionmark.circle")
        }
    }
}

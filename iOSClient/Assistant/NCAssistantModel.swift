//
//  NCAssistantModel.swift
//  Nextcloud
//
//  Created by Milen on 08.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import NextcloudKit
import SwiftUI

class NCAssistantModel: ObservableObject {
    @Published var types: [NKTextProcessingTaskType] = []
    private var tasks: [NKTextProcessingTask] = []
    @Published var filteredTasks: [NKTextProcessingTask] = []
    @Published var selectedTaskType: NKTextProcessingTaskType?

    private let excludedTypeIds = ["OCA\\ContextChat\\TextProcessing\\ContextChatTaskType"]

    init() {
        load()
    }

    func load() {
        loadTypes()
        loadTasks()
    }

    func filterTasks(ofType type: NKTextProcessingTaskType?) {
        if let type {
            self.filteredTasks = tasks.filter({ $0.type == type.id })
        } else {
            self.filteredTasks = tasks
        }
    }

    func selectTaskType(_ type: NKTextProcessingTaskType?) {
        selectedTaskType = type
        filterTasks(ofType: self.selectedTaskType)
    }

    func schedule(input: String) {
        NextcloudKit.shared.textProcessingSchedule(input: input, typeId: selectedTaskType?.id ?? "", identifier: "assistant") { account, task, data, error in
            self.loadTasks()
        }
    }

    private func loadTypes() {
        NextcloudKit.shared.textProcessingGetTypes { _, types, _, _ in
            guard let filteredTypes = types?.filter({ !self.excludedTypeIds.contains($0.id ?? "")}) else { return }

            self.types = filteredTypes
        }
    }

    private func loadTasks(appId: String = "assistant") {
        NextcloudKit.shared.textProcessingTaskList(appId: appId) { _, tasks, _, error in
            guard let tasks = tasks else { return }
            self.tasks = tasks
            self.filterTasks(ofType: self.selectedTaskType)
        }
    }
}

extension NCAssistantModel {
    public func loadDummyData() {
        let loremIpsum = """
        Lorem ipsum dolor sit amet, consectetur adipiscing
        elit, sed do eiusmod tempor incididunt ut labore et
        dolore magna aliqua. Ut enim ad minim veniam, quis
        nostrud exercitation ullamco laboris nisi ut aliquip
        ex ea commodo consequat. Duis aute irure dolor in
        reprehenderit in voluptate velit esse cillum dolore
        eu fugiat nulla pariatur.
        """

        var tasks: [NKTextProcessingTask] = []

        for index in 1...10 {
            tasks.append(NKTextProcessingTask(id: index, type: "OCP\\TextProcessing\\FreePromptTaskType", status: index, userId: "christine", appId: "assistant", input: loremIpsum, output: loremIpsum, identifier: "", completionExpectedAt: 1712666412))
        }

        self.tasks = tasks
        self.filteredTasks = tasks
        self.selectedTaskType = NKTextProcessingTaskType(id: "OCP\\TextProcessing\\FreePromptTaskType", name: "Free Prompt", description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua")
        self.types = [
            NKTextProcessingTaskType(id: "1", name: "Free Prompt", description: ""),
            NKTextProcessingTaskType(id: "2", name: "Summarize", description: ""),
            NKTextProcessingTaskType(id: "3", name: "Generate headline", description: ""),
            NKTextProcessingTaskType(id: "4", name: "Reformulate", description: ""),
        ]
    }
}

extension NKTextProcessingTask {
    struct StatusInfo {
        let stringKey, imageSystemName: String
        let imageColor: Color
    }

    var statusInfo: StatusInfo {
        return switch status {
        case 1:
            StatusInfo(stringKey: "_assistant_task_scheduled_", imageSystemName: "clock", imageColor: .blue)
        case 2:
            StatusInfo(stringKey: "_assistant_task_in_progress_", imageSystemName: "clock.badge", imageColor: .gray)
        case 3:
            StatusInfo(stringKey: "_assistant_task_completed_", imageSystemName: "checkmark.circle", imageColor: .green)
        case 4:
            StatusInfo(stringKey: "_assistant_task_failed_", imageSystemName: "exclamationmark.circle", imageColor: .red)
        default:
            StatusInfo(stringKey: "_assistant_task_unknown_", imageSystemName: "questionmark.circle", imageColor: .black)
        }
    }
}

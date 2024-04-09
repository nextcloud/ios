//
//  NCAssistantModel.swift
//  Nextcloud
//
//  Created by Milen on 08.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import NextcloudKit

class NCAssistantModel: ObservableObject {
    @Published var types: [NKTextProcessingTaskType] = []
    private var tasks: [NKTextProcessingTask] = []
    @Published var filteredTasks: [NKTextProcessingTask] = []
    @Published var selectedTaskType: NKTextProcessingTaskType?

    private let excludedTypeIds = ["OCA\\ContextChat\\TextProcessing\\ContextChatTaskTyp"]

    init() {
        loadTypes()
        loadTasks()
    }

    private func loadTypes() {
        NextcloudKit.shared.textProcessingGetTypes { _, types, _, _ in
            guard let filteredTypes = types?.filter({ !self.excludedTypeIds.contains($0.id ?? "")}) else { return }

            self.types = filteredTypes
        }
    }

    func filterTasks(ofType type: NKTextProcessingTaskType?) {
        if let type {
            self.filteredTasks = tasks.filter({ $0.type == type.id })
        } else {
            self.filteredTasks = tasks
        }
//        return tasks.filter { $0.type == type.id }
    }

    private func loadTasks(appId: String = "assistant") {
        NextcloudKit.shared.textProcessingTaskList(appId: appId) { _, tasks, _, error in

            guard let tasks = tasks else { return }
            self.tasks = tasks
            self.filterTasks(ofType: self.selectedTaskType)
        }
    }

    func selectTaskType(_ type: NKTextProcessingTaskType?) {
        selectedTaskType = type
        filterTasks(ofType: self.selectedTaskType)
    }

    private func schedule() {
        
    }
}

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
    @Published public var types: [NKTextProcessingTaskTypes] = []
    @Published public var tasks: [NKTextProcessingTask] = []

    private let excludedTypeIds = ["OCA\\ContextChat\\TextProcessing\\ContextChatTaskType"]

    init() {
        loadTypes()
        loadTasks()
    }

    private func loadTypes() {
        NextcloudKit.shared.textProcessingGetTypes { _, types, _, _ in
            guard let filteredTypes = types?.filter({ self.excludedTypeIds.contains($0.id ?? "")}) else { return }

            self.types = filteredTypes
        }
    }

    private func loadTasks(appId: String = "assistant") {
        NextcloudKit.shared.textProcessingTaskList(appId: appId) { _, tasks, _, error in

            print(error)
            self.tasks = tasks ?? []
        }
    }

    private func schedule() {
        
    }
}

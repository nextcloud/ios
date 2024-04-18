//
//  NCAssistantTaskDetail.swift
//  Nextcloud
//
//  Created by Milen on 10.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

struct NCAssistantTaskDetail: View {
    @EnvironmentObject var model: NCAssistantTask
    @State private var tab = 0

    let task: NKTextProcessingTask

    var body: some View {
        VStack {
            Picker("", selection: $tab) {
                Text(NSLocalizedString("_input_", comment: "")).tag(0)
                Text(NSLocalizedString("_output_", comment: "")).tag(1)
            }
            .padding(.bottom, 10)
            .pickerStyle(.segmented)

            ScrollView {
                Text(tab == 0 ? (model.selectedTask?.input ?? "") : (model.selectedTask?.output ?? ""))
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.gray.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))

            HStack(alignment: .center) {
                Label(
                    title: { Text(NSLocalizedString(model.selectedTask?.statusInfo.stringKey ?? "", comment: "")) },
                    icon: { Image(systemName: model.selectedTask?.statusInfo.imageSystemName ?? "").renderingMode(.original) }
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                if let completionExpectedAt = task.completionExpectedAt {
                    Text(NCUtility().dateDiff(.init(timeIntervalSince1970: TimeInterval(completionExpectedAt))))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding()

        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(NSLocalizedString("_task_details_", comment: ""))
        .padding()
        .onAppear {
            model.selectTask(task)
        }
    }
}

#Preview {
    let model = NCAssistantTask()

    return NCAssistantTaskDetail(task: NKTextProcessingTask(id: 1, type: "OCP\\TextProcessing\\FreePromptTaskType", status: 1, userId: "christine", appId: "assistant", input: "", output: "", identifier: "", completionExpectedAt: 1712666412))
        .environmentObject(model)
        .onAppear {
            model.loadDummyData()
        }
}

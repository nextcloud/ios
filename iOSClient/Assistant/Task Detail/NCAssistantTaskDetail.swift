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
    let task: NKTextProcessingTask

    var body: some View {
        ZStack(alignment: .bottom) {
            InputOutputScrollView(task: task)

            BottomDetailsBar(task: task)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(NSLocalizedString("_task_details_", comment: ""))
        .onAppear {
            model.selectTask(task)
        }
    }
}

#Preview {
    let model = NCAssistantTask(controller: nil)

    return NCAssistantTaskDetail(task: NKTextProcessingTask(id: 1, type: "OCP\\TextProcessing\\FreePromptTaskType", status: 1, userId: "christine", appId: "assistant", input: "", output: "", identifier: "", completionExpectedAt: 1712666412))
        .environmentObject(model)
        .onAppear {
            model.loadDummyData()
        }
}

struct InputOutputScrollView: View {
    @EnvironmentObject var model: NCAssistantTask
    let task: NKTextProcessingTask

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(NSLocalizedString("_input_", comment: "")).font(.headline)
                    .padding(.top, 10)

                Text(model.selectedTask?.input ?? "")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
                    .background(Color(NCBrandColor.shared.textColor2).opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))

                Text(NSLocalizedString("_output_", comment: "")).font(.headline)
                    .padding(.top, 10)

                Text(model.selectedTask?.output ?? "")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
                    .background(Color(NCBrandColor.shared.textColor2).opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))

            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct BottomDetailsBar: View {
    @EnvironmentObject var model: NCAssistantTask
    let task: NKTextProcessingTask

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom) {
                Label(
                    title: {
                        Text(NSLocalizedString(model.selectedTask?.statusInfo.stringKey ?? "", comment: ""))
                    }, icon: {
                        Image(systemName: model.selectedTask?.statusInfo.imageSystemName ?? "")
                            .renderingMode(.original)
                            .font(Font.system(.body).weight(.light))
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                if let completionExpectedAt = task.completionExpectedAt {
                    Text(NCUtility().dateDiff(.init(timeIntervalSince1970: TimeInterval(completionExpectedAt))))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding()
            .background(.bar)
            .frame(alignment: .bottom)
        }
    }
}

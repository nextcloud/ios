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
    @EnvironmentObject var model: NCAssistantModel
    let task: AssistantTask

    var body: some View {
        ZStack(alignment: .bottom) {
            InputOutputScrollView(task: task)

            BottomDetailsBar(task: task)
        }
        .toolbar {
            Button(action: {
                model.shareTask(task)
            }, label: {
                Image(systemName: "square.and.arrow.up")
            })
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(NSLocalizedString("_task_details_", comment: ""))
        .onAppear {
            model.selectTask(task)
        }
    }
}

#Preview {
    let model = NCAssistantModel(controller: nil)

    NCAssistantTaskDetail(task: model.selectedTask!)
        .environmentObject(model)
        .onAppear {
            model.loadDummyData()
        }
}

struct InputOutputScrollView: View {
    @EnvironmentObject var model: NCAssistantModel
    let task: AssistantTask

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(NSLocalizedString("_input_", comment: "")).font(.headline)
                    .padding(.top, 10)

                Text(model.selectedTask?.input?.input ?? "")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
                    .background(Color(NCBrandColor.shared.textColor2).opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
                    .textSelection(.enabled)

                Text(NSLocalizedString("_output_", comment: "")).font(.headline)
                    .padding(.top, 10)

                Text(model.selectedTask?.output?.output ?? "")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
                    .background(Color(NCBrandColor.shared.textColor2).opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
                    .textSelection(.enabled)
            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct BottomDetailsBar: View {
    @EnvironmentObject var model: NCAssistantModel
    let task: AssistantTask

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                StatusInfo(task: task, showStatusText: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.bar)
                    .frame(alignment: .bottom)
            }
        }
    }
}

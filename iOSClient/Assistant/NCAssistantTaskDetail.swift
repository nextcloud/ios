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
    let task: NKTextProcessingTask
    @State private var tab = 0

    var body: some View {
        NavigationView {
            VStack {
                Picker("", selection: $tab) {
                    Text("Input").tag(0)
                    Text("Output").tag(1)
                }
                .padding(.bottom, 10)
                .pickerStyle(.segmented)

                ScrollView {
                    Text(tab == 0 ? (task.input ?? "") : (task.output ?? ""))
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(.gray.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))

                HStack {
                    Label(
                        title: { Text(NSLocalizedString(task.statusInfo.stringKey, comment: "")) },
                        icon: { Image(systemName: task.statusInfo.imageSystemName).renderingMode(.original) }
                    )
//                    .foregroundStyle(.primary)
                }
                .padding()

            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Task details")
            .padding()
        }
    }
}

#Preview {
    let loremIpsum = """
    Lorem ipsum dolor sit amet, consectetur adipiscing
    elit, sed do eiusmod tempor incididunt ut labore et
    dolore magna aliqua. Ut enim ad minim veniam, quis
    nostrud exercitation ullamco laboris nisi ut aliquip
    ex ea commodo consequat. lit esse cillum dolore
    eu fugiat nulla pariatur. 
    """

    return NCAssistantTaskDetail(task: NKTextProcessingTask(id: 1, type: "OCP\\TextProcessing\\FreePromptTaskType", status: 3, userId: "christine", appId: "assistant", input: loremIpsum, output: loremIpsum, identifier: "", completionExpectedAt: 1712666412))
}

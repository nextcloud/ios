//
//  NCAssistant.swift
//  Nextcloud
//
//  Created by Milen on 03.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit
import ExpandableText

struct NCAssistant: View {
    @EnvironmentObject var model: NCAssistantModel
    @State var presentNewTaskDialog = false
    @State var taskText = ""

    var body: some View {
        NavigationView {
            VStack {
                ScrollView(.horizontal) {
                    LazyHStack {
                        TypeButton(model: model, taskType: nil)

                        ForEach(model.types, id: \.id) { type in
                            TypeButton(model: model, taskType: type)
                        }
                    }
                    .frame(height: 50)
                    .padding()
                }.toolbar {
                    NavigationLink(destination: NCAssistantCreateNewTask()) {
                        Image(systemName: "plus")
                    }
                    .disabled(model.selectedTaskType == nil)
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Assistant")

                List(model.filteredTasks, id: \.id) { task in
                    TaskItem(task: task)
                }
            }
        }
        .environmentObject(model)
    }
}

#Preview {
    let model = NCAssistantModel()

    return NCAssistant()
        .environmentObject(model)
        .onAppear {
            model.loadDummyTasks()
        }
}

struct TypeButton: View {
    let model: NCAssistantModel
    let taskType: NKTextProcessingTaskType?

    var body: some View {
        Button {
            model.selectTaskType(taskType)
        } label: {
            Text(taskType?.name ?? "All").font(.title2).foregroundStyle(.white)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 10)
        .background(.gray, ignoresSafeAreaEdges: [])
        .clipShape(.capsule)
    }
}

struct TaskItem: View {
    let task: NKTextProcessingTask

    var body: some View {
        let loremIpsum = """
        Lorem ipsum dolor sit amet, consectetur adipiscing
        elit, sed do eiusmod tempor incididunt ut labore et
        dolore magna aliqua. Ut enim ad minim veniam, quis
        nostrud exercitation ullamco laboris nisi ut aliquip
        ex ea commodo consequat. Duis aute irure dolor in
        reprehenderit in voluptate velit esse cillum dolore
        eu fugiat nulla pariatur.
        """

        NavigationLink(destination: NCAssistantTaskDetail()) {
            VStack(alignment: .leading) {
                Text(loremIpsum)
                    .lineLimit(4)

                HStack {
                    Label(
                            title: { Text(NSLocalizedString(task.statusInfo.stringKey, comment: "")) },
                            icon: { Image(systemName: task.statusInfo.imageSystemName).renderingMode(.original) }
                        )
                        .padding(.top, 1)
                    .labelStyle(CustomLabelStyle())


                    Text(NCUtility().dateDiff(.init(timeIntervalSince1970: TimeInterval(task.completionExpectedAt ?? 0))))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

struct CustomLabelStyle: LabelStyle {
    var spacing: Double = 5

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

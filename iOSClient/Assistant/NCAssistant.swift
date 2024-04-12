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
            List(model.filteredTasks, id: \.id) { task in
                TaskItem(task: task)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: -25) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack {
                        TypeButton(model: model, taskType: nil)

                        ForEach(model.types, id: \.id) { type in
                            TypeButton(model: model, taskType: type)
                        }
                    }
                    .padding(20)
                    .frame(height: 50)
                }
            }
            .toolbar {
                NavigationLink(destination: NCAssistantCreateNewTask()) {
                    Image(systemName: "plus")
                }
                .disabled(model.selectedTaskType == nil)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Assistant")
        }
        .environmentObject(model)
    }
}

#Preview {
    let model = NCAssistantModel()

    return NCAssistant()
        .environmentObject(model)
        .onAppear {
            model.loadDummyData()
        }
}

struct TypeButton: View {
    let model: NCAssistantModel
    let taskType: NKTextProcessingTaskType?

    var body: some View {
        let color: Any = model.selectedTaskType?.id == taskType?.id ? NCBrandColor.shared.brandElement : Material.ultraThinMaterial
        Button {
            model.selectTaskType(taskType)
        } label: {
            Text(taskType?.name ?? NSLocalizedString("_all_", comment: "")).font(.body)
        }
        .padding(.horizontal)
        .padding(.vertical, 7)
        .foregroundStyle(.primary)
        .background(Color(NCBrandColor.shared.brandElement), ignoresSafeAreaEdges: [])
        .clipShape(.capsule)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: RoundedCornerStyle.continuous)
                .stroke(.tertiary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TaskItem: View {
    let task: NKTextProcessingTask

    var body: some View {
        NavigationLink(destination: NCAssistantTaskDetail(task: task)) {
            VStack(alignment: .leading) {
                Text(task.input ?? "")
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

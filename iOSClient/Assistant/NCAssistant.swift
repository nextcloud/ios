//
//  NCAssistant.swift
//  Nextcloud
//
//  Created by Milen on 03.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

struct NCAssistant: View {
    @EnvironmentObject var model: NCAssistantModel
    @State var presentNewTaskDialog = false
    @State var taskText = ""
    @State var showHud = true

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {

                List(model.filteredTasks, id: \.id) { task in
                    TaskItem(task: task)
                }
                .refreshable {
                    model.load()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .top, spacing: -10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack {
                            TypeButton(taskType: nil)

                            ForEach(model.types, id: \.id) { type in
                                TypeButton(taskType: type)
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


                HUDView(showHUD: .constant(false), textLabel: NSLocalizedString("_wait_", comment: ""), image: "doc.badge.arrow.up")
                    .frame(alignment: .top)

            }
            .environmentObject(model)
        }
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
    @EnvironmentObject var model: NCAssistantModel
    let taskType: NKTextProcessingTaskType?

    var body: some View {
        Button {
            model.selectTaskType(taskType)
        } label: {
            Text(taskType?.name ?? NSLocalizedString("_all_", comment: "")).font(.body)
        }
        .padding(.horizontal)
        .padding(.vertical, 7)
        .foregroundStyle(model.selectedTaskType?.id == taskType?.id ? .white : .primary)
        .if(model.selectedTaskType?.id == taskType?.id) { view in
            view.background(Color(NCBrandColor.shared.brandElement))
        }
        .if(model.selectedTaskType?.id != taskType?.id) { view in
            view.background(.ultraThinMaterial)
        }
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

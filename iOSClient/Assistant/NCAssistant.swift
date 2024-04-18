//
//  NCAssistant.swift
//  Nextcloud
//
//  Created by Milen on 03.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit
import PopupView

struct NCAssistant: View {
    @EnvironmentObject var model: NCAssistantTask
    @State var presentNewTaskDialog = false
    @State var input = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                TaskList()

                if model.filteredTasks.isEmpty, !model.isLoading {
                    EmptyTasksView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("_close_", comment: "")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: NCAssistantCreateNewTask()) {
                        Image(systemName: "plus")
                    }
                    .disabled(model.selectedTaskType == nil)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(NSLocalizedString("_assistant_", comment: ""))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: -10) {
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack {
                            ForEach(model.types, id: \.id) { type in
                                TypeButton(taskType: type, scrollProxy: scrollProxy)
                            }
                        }
                        .padding(20)
                        .frame(height: 50)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .popup(isPresented: $model.hasError) {
            Text(NSLocalizedString("_error_occurred_", comment: ""))
                .padding()
                .background(.red)
                .cornerRadius(30.0)
        } customize: {
            $0
                .type(.floater())
                .autohideIn(2)
                .position(.bottom)
        }
        .environmentObject(model)
    }
}

#Preview {
    let model = NCAssistantTask()

    return NCAssistant()
        .environmentObject(model)
        .onAppear {
            model.loadDummyData()
        }
}

struct TaskList: View {
    @EnvironmentObject var model: NCAssistantTask

    var body: some View {
        List(model.filteredTasks, id: \.id) { task in
            TaskItem(task: task)
        }
        .refreshable {
            model.load()
        }
    }
}

struct TypeButton: View {
    @EnvironmentObject var model: NCAssistantTask

    let taskType: NKTextProcessingTaskType?
    var scrollProxy: ScrollViewProxy

    var body: some View {
        Button {
            model.selectTaskType(taskType)

            withAnimation {
                scrollProxy.scrollTo(taskType?.id, anchor: .center)
            }
        } label: {
            Text(taskType?.name ?? "").font(.body)
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
        .id(taskType?.id)
    }
}

struct TaskItem: View {
    @EnvironmentObject var model: NCAssistantTask
    @State var showDeleteConfirmation = false
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

                    if let completionExpectedAt = task.completionExpectedAt {
                        Text(NCUtility().dateDiff(.init(timeIntervalSince1970: TimeInterval(completionExpectedAt))))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .swipeActions {
                Button(NSLocalizedString("_delete_", comment: "")) {
                    showDeleteConfirmation = true
                }
                .tint(.red)
            }
            .confirmationDialog("", isPresented: $showDeleteConfirmation) {
                Button(NSLocalizedString("_delete_", comment: ""), role: .destructive) {
                    withAnimation {
                        model.deleteTask(task)
                    }
                }
            }
        }
    }
}

private struct CustomLabelStyle: LabelStyle {
    var spacing: Double = 5

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

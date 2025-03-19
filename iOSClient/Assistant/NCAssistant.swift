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
    @EnvironmentObject var model: NCAssistantModel
    @State var input = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                TaskList()

                if model.isLoading, !model.isRefreshing {
                    ProgressView()
                        .controlSize(.regular)
                }

                if model.types.isEmpty, !model.isLoading {
                    NCAssistantEmptyView(titleKey: "_no_types_", subtitleKey: "_no_types_subtitle_")
                } else if model.filteredTasks.isEmpty, !model.isLoading {
                    NCAssistantEmptyView(titleKey: "_no_tasks_", subtitleKey: "_create_task_subtitle_")
                }

            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("_close_")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: NCAssistantCreateNewTask()) {
                        Image(systemName: "plus")
                            .font(Font.system(.body).weight(.light))
                            .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                    }
                    .disabled(model.selectedType == nil)
                    .accessibilityIdentifier("CreateButton")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(NSLocalizedString("_assistant_", comment: ""))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: -10) {
                TypeList()
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
        .accentColor(Color(NCBrandColor.shared.iconImageColor))
        .environmentObject(model)
    }
}

#Preview {
    let model = NCAssistantModel(controller: nil)

    NCAssistant()
        .environmentObject(model)
        .onAppear {
            model.loadDummyData()
        }
}

struct TaskList: View {
    @EnvironmentObject var model: NCAssistantModel
    @State var presentEditTask = false
    @State var showDeleteConfirmation = false

    @State var taskToEdit: AssistantTask?
    @State var taskToDelete: AssistantTask?

    var body: some View {
        List(model.filteredTasks, id: \.id) { task in
            TaskItem(showDeleteConfirmation: $showDeleteConfirmation, taskToDelete: $taskToDelete, task: task)
                .contextMenu {
                    Button {
                        model.shareTask(task)
                    } label: {
                        Label {
                            Text("_share_")
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }

                    Button {
                        model.scheduleTask(input: task.input?.input ?? "")
                    } label: {
                        Label {
                            Text("_retry_")
                        } icon: {
                            Image(systemName: "arrow.trianglehead.clockwise")
                        }
                    }
                    .accessibilityIdentifier("TaskRetryContextMenu")

                    Button {
                        taskToEdit = task
                        presentEditTask = true
                    } label: {
                        Label {
                            Text("_edit_")
                        } icon: {
                            Image(systemName: "pencil")
                        }
                    }
                    .accessibilityIdentifier("TaskEditContextMenu")

                    Button(role: .destructive) {
                        taskToDelete = task
                        showDeleteConfirmation = true
                    } label: {
                        Label {
                            Text("_delete_")
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                    .accessibilityIdentifier("TaskDeleteContextMenu")
                }
                .accessibilityIdentifier("TaskContextMenu")
        }
        .if(!model.types.isEmpty) { view in
            view.refreshable {
                model.refresh()
            }
        }
        .confirmationDialog("", isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("_delete_", comment: ""), role: .destructive) {
                withAnimation {
                    guard let taskToDelete else { return }
                    model.deleteTask(taskToDelete)
                }
            }
        }
        .sheet(isPresented: $presentEditTask) { [taskToEdit] in
            NavigationView {
                NCAssistantCreateNewTask(text: taskToEdit?.input?.input ?? "", editMode: true)
            }
        }
    }
}

struct TypeButton: View {
    @EnvironmentObject var model: NCAssistantModel

    let taskType: TaskTypeData?
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
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial)
        .if(model.selectedType?.id == taskType?.id) { view in
            view
                .foregroundStyle(.white)
                .background(Color(NCBrandColor.shared.getElement(account: model.controller?.account)))

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
    @EnvironmentObject var model: NCAssistantModel
    @Binding var showDeleteConfirmation: Bool
    @Binding var taskToDelete: AssistantTask?
    var task: AssistantTask

    var body: some View {
        NavigationLink(destination: NCAssistantTaskDetail(task: task)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(task.input?.input ?? "")
                    .lineLimit(1)

                if let output = task.output?.output, !output.isEmpty {
                    Text(output)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label(
                        title: {
                            Text(task.statusDate)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        },
                        icon: {
                            Image(systemName: task.statusInfo.imageSystemName)
                                .renderingMode(.original)
                                .font(Font.system(.body).weight(.light))
                        }
                    )
                    .labelStyle(CustomLabelStyle())
                }
            }
            .swipeActions {
                Button(NSLocalizedString("_delete_", comment: "")) {
                    taskToDelete = task
                    showDeleteConfirmation = true
                }
                .tint(.red)
            }
        }
    }
}

struct TypeList: View {
    @EnvironmentObject var model: NCAssistantModel

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(model.types, id: \.id) { type in
                        TypeButton(taskType: type, scrollProxy: scrollProxy)
                    }
                }
                .padding(20)
                .frame(height: 50)
            }
            .background(.ultraThinMaterial)
        }
    }
}

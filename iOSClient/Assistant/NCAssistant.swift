// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit
import PopupView

struct NCAssistant: View {
    @State var assistantModel: NCAssistantModel
    @State var chatModel: NCAssistantChatModel
    
    @State var input = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                if assistantModel.types.isEmpty, !assistantModel.isLoading {
                    NCAssistantEmptyView(titleKey: "_no_types_", subtitleKey: "_no_types_subtitle_")
                } else if assistantModel.isSelectedTypeChat {
                    NCAssistantChat()
                } else {
                    TaskList()
                }

                if assistantModel.isLoading, !assistantModel.isRefreshing {
                    ProgressView()
                        .controlSize(.regular)
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
                    NavigationLink(destination: NCAssistantChatSessions(model: $chatModel)) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(Font.system(.body).weight(.light))
                            .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                    }
                    .disabled(assistantModel.selectedType == nil)
                    .accessibilityIdentifier("SessionsButton")
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
        .popup(isPresented: $assistantModel.hasError) {
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
        .environment(assistantModel)
        .environment(chatModel)
    }
}

#Preview {
    @Previewable @State var chatModel = NCAssistantChatModel(controller: nil)
    let model = NCAssistantModel(controller: nil)

    NCAssistant(assistantModel: model, chatModel: chatModel)
        .onAppear {
            model.loadDummyData()
        }
}

struct TaskList: View {
    @Environment(NCAssistantModel.self) var model
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
        .safeAreaInset(edge: .bottom) {
//            ChatInputField(isLoading: model._isLoading) { input in
//                model.scheduleTask(input: input)
//            }
        }

        if model.filteredTasks.isEmpty, !model.isLoading {
            NCAssistantEmptyView(titleKey: "_no_tasks_", subtitleKey: "_create_task_subtitle_")
        }
    }
}

struct TypeButton: View {
    @Environment(NCAssistantModel.self) var model

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
    @Environment(NCAssistantModel.self) var model
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
    @Environment(NCAssistantModel.self) var model

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

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
    @State var presentNewTaskDialog = false
    @State var presentEditTask = false
    @State var input = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                TaskList(presentEditTask: $presentEditTask)

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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(NSLocalizedString("_assistant_", comment: ""))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: -10) {
                TypeList()
            }
        }
        .background( // navigationDestination
            NavigationLink(destination: NCAssistantCreateNewTask(), isActive: $presentEditTask) { EmptyView() }
          )
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

    return NCAssistant()
        .environmentObject(model)
        .onAppear {
            model.loadDummyData()
        }
}

struct TaskList: View {
    @EnvironmentObject var model: NCAssistantModel
    @Binding var presentEditTask: Bool

    var body: some View {
        List(model.filteredTasks, id: \.id) { task in
            TaskItem(task: task)
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
                        presentEditTask.toggle()
                    } label: {
                        Label {
                            Text("_edit_")
                        } icon: {
                            Image(systemName: "pencil")
                        }
                    }
                }
        }
        .if(!model.types.isEmpty) { view in
            view.refreshable {
                model.refresh()
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
    @State var showDeleteConfirmation = false
    let task: AssistantTask

    var body: some View {
        NavigationLink(destination: NCAssistantTaskDetail(task: task)) {
            VStack(alignment: .leading) {
                Text(task.input?.input ?? "")
                    .lineLimit(1)

                Text(task.output?.output ?? "")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

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
                    .padding(.top, 1)
                    .labelStyle(CustomLabelStyle())
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

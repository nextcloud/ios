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
    let useV2 = true
    @EnvironmentObject var model: NCAssistantTask
    @EnvironmentObject var modelV2: NCAssistantTaskV2
    @State var presentNewTaskDialog = false
    @State var input = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            TaskList()

            EmptyView()

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
                    .disabled(useV2 ? modelV2.selectedType == nil : model.selectedType == nil)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(NSLocalizedString("_assistant_", comment: ""))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: -10) {
                ExtractedView()
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
    let model = NCAssistantTask(controller: nil)

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
                .contextMenu {
                    Button {
                    } label: {
                        Label {
                            Text("_copy_")
                        } icon: {
                            Image(systemName: "document.on.document")
                        }

                    }

                    //                    Button {
                    //                        Label {
                    //                        } icon: {
                    //                            Image(systemImage: "copy")
                    //                        }
                    //
                    //                    }
                    Button("Test") {

                    }
                }
        }
        .if(!model.types.isEmpty) { view in
            view.refreshable {
                model.load()
            }
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
        .foregroundStyle(model.selectedType?.id == taskType?.id ? .white : .primary)
        .if(model.selectedType?.id == taskType?.id) { view in
            view.background(Color(NCBrandColor.shared.getElement(account: model.controller?.account)))
        }
        .if(model.selectedType?.id != taskType?.id) { view in
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
                    .lineLimit(1)

                Text(task.output ?? "")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

                HStack {
                    Label(
                        title: {
                            Text(NSLocalizedString(task.status == 3 /*Completed*/ ? NCUtility().dateDiff(.init(timeIntervalSince1970: TimeInterval(task.completionExpectedAt ?? 0))) : task.statusInfo.stringKey, comment: ""))
                        },
                        icon: {
                            Image(systemName: task.statusInfo.imageSystemName)
                                .renderingMode(.original)
                                .font(Font.system(.body).weight(.light))
                        }
                    )
                    .padding(.top, 1)
                    .labelStyle(CustomLabelStyle())

//                    if let completionExpectedAt = task.completionExpectedAt {
//                        Text(NCUtility().dateDiff(.init(timeIntervalSince1970: TimeInterval(completionExpectedAt))))
//                            .frame(maxWidth: .infinity, alignment: .trailing)
//                            .foregroundStyle(.tertiary)
//                    }
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

struct EmptyView: View {
    var body: some View {
        {

            if useV2 {
                if ((modelV2.types?.isEmpty) != nil), !modelV2.isLoading {
                    NCAssistantEmptyView(titleKey: "_no_types_", subtitleKey: "_no_types_subtitle_")
                } else if modelV2.filteredTasks.isEmpty, !model.isLoading {
                    NCAssistantEmptyView(titleKey: "_no_tasks_", subtitleKey: "_create_task_subtitle_")
                }
            } else {
                if model.types.isEmpty, !model.isLoading {
                    NCAssistantEmptyView(titleKey: "_no_types_", subtitleKey: "_no_types_subtitle_")
                } else if model.filteredTasks.isEmpty, !model.isLoading {
                    NCAssistantEmptyView(titleKey: "_no_tasks_", subtitleKey: "_create_task_subtitle_")
                }
            }
        }
    }
}

struct ExtractedView: View {
    @EnvironmentObject var model: NCAssistantTask
    @EnvironmentObject var modelV2: NCAssistantTaskV2
    let useV2: Bool

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    if useV2 {
                        ForEach(modelV2.types, id: \.id) { type in
                            TypeButton(taskType: type, scrollProxy: scrollProxy)
                        }
                    } else {
                        ForEach(model.types, id: \.id) { type in
                            TypeButton(taskType: type, scrollProxy: scrollProxy)
                        }
                    }
                }
                .padding(20)
                .frame(height: 50)
            }
            .background(.ultraThinMaterial)
        }
    }
}

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
    @ObservedObject var model = NCAssistantModel()
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

                    //                    Button {
                    NavigationLink(destination: NCAssistantCreateNewTask()) {
                        Image(systemName: "plus")
                    }
                    .disabled(model.selectedTaskType == nil)

                    //                        //                        presentNewTaskDialog = true
                    //                    } label: {
                    //                        Image(systemName: "plus")
                    //                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Assistant")

                List(model.filteredTasks, id: \.id) { task in
                    Text(task.input ?? "")
                }
            }
        }
        .environmentObject(model)
        //        .alert(model.selectedTaskType?.name ?? "", isPresented: $presentNewTaskDialog) {
        //            TextEditor(text: $taskText)
        //                .frame(height: 100)
        //            Button("OK") {
        //
        //            }
        //            Button("Cancel", role: .cancel) { }
        //        } message: {
        //            Text(model.selectedTaskType?.description ?? "")
        //
        //        }
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
        .background(.blue, ignoresSafeAreaEdges: [])
        .cornerRadius(5)
    }
}

#Preview {
    NCAssistant()
}

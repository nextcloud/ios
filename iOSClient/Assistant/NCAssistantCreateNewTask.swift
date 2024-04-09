//
//  NCAssistantCreateNewTask.swift
//  Nextcloud
//
//  Created by Milen on 09.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NCAssistantCreateNewTask: View {
    @EnvironmentObject var model: NCAssistantModel
    @State var text = ""

    var body: some View {
//        NavigationView {
            VStack {
                Text(model.selectedTaskType?.description ?? "")
                TextEditor(text: $text)
//                    .foregroundStyle(.gray)

            }
            .toolbar {
                Button(action: {
                }, label: {
                    Text("Add")
                })
            }
            .navigationTitle("New " + (model.selectedTaskType?.name ?? "") + " task")
            .navigationBarTitleDisplayMode(.inline)
            .padding()

//        }

    }
}

#Preview {
    NCAssistantCreateNewTask()
        .environmentObject(NCAssistantModel())
}

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
    @State var text = "eweaesda"

    var body: some View {
        NavigationView {
            VStack {
                Text(model.selectedTaskType?.name ?? "Test")
                TextEditor(text: $text)
                    .toolbar {
                        Button(action: {

                        }, label: {
                            Text("Add")
                        })
                    }
            }
            .padding()

                .navigationTitle("New " + (model.selectedTaskType?.name ?? "") + " Task")

                .navigationBarTitleDisplayMode(.inline)
        }

    }
}

#Preview {
    NCAssistantCreateNewTask()
        .environmentObject(NCAssistantModel())
}

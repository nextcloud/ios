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
    @FocusState private var inFocus: Bool

    var body: some View {
        VStack {
            Text(model.selectedTaskType?.description ?? "")
                .frame(alignment: .top)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Input")
                        .padding(24)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $text)
                    .padding()
                    .transparentScrolling()
                    .background(.gray.opacity(0.1))

                .focused($inFocus)
            }
            .background(.gray.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))
        }
        .toolbar {
            Button(action: {
            }, label: {
                Text(NSLocalizedString("_create_", comment: ""))
            })
        }
        .navigationTitle("New " + (model.selectedTaskType?.name ?? "") + " task")
        .navigationBarTitleDisplayMode(.inline)
        .padding()
        .onAppear {
            inFocus = true
        }
    }
}

#Preview {
    let model = NCAssistantModel()

    return NCAssistantCreateNewTask()
        .environmentObject(model)
        .onAppear {
            model.loadDummyData()
        }}

private extension View {
    func transparentScrolling() -> some View {
        if #available(iOS 16.0, *) {
            return scrollContentBackground(.hidden)
        } else {
            return onAppear {
                UITextView.appearance().backgroundColor = .clear
            }
        }
    }
}

//
//  NCAssistant.swift
//  Nextcloud
//
//  Created by Milen on 03.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NCAssistant: View {
    @ObservedObject var model = NCAssistantModel()

    var body: some View {
        NavigationView {
            VStack {
                ScrollView(.horizontal) {
                    LazyHStack {
                        TypeButton(text: "All")

                        ForEach(model.types, id: \.id) { type in
                            TypeButton(text: type.name ?? "")
                        }
                    }
                    .frame(height: 50)
                    .padding()
                }.toolbar {
                    Button {
                    } label: {
                        Image(systemName: "plus")
                    }
                }

//                List {
//                    Text("test")
//                    Text("test")
//                    Text("test")
//                    Text("test")
//                    Text("test")
//                }

                List(model.tasks, id: \.id) { task in
                    Text(task.output ?? "")
                }
            }


        }

    }
}

#Preview {
    NCAssistant()
}

struct TypeButton: View {
    let text: String

    var body: some View {
        Button {

        } label: {
            Text(text).font(.title2).foregroundStyle(.white)
        }
        //        .frame(height: 20)
        .padding(.horizontal, 30)
        .padding(.vertical, 10)
        .background(.blue, ignoresSafeAreaEdges: [])
        .cornerRadius(5)
    }
}

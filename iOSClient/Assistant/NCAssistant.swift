//
//  NCAssistant.swift
//  Nextcloud
//
//  Created by Milen on 03.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NCAssistant: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top) {
                TypeButton()
                TypeButton()
                TypeButton()
                TypeButton()
                TypeButton()
                TypeButton()
                TypeButton()
                TypeButton()
                TypeButton()
                TypeButton()
                TypeButton()
            }
            .padding()
        }

        List {
            Text("WOIW")
        }
    }
}

#Preview {
    NCAssistant()
}

struct TypeButton: View {
    var body: some View {
        Button {

        } label: {
            Text("Test").font(.title2).foregroundStyle(.white)
        }
//        .frame(height: 20)
        .padding(.horizontal, 30)
        .padding(.vertical, 10)
        .background(.blue, ignoresSafeAreaEdges: [])
        .cornerRadius(5)
    }
}

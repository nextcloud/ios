//
//  EmptyTasksView.swift
//  Nextcloud
//
//  Created by Milen on 16.04.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct EmptyTasksView: View {
    var body: some View {
        VStack {
            Image(systemName: "sparkles")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color(NCBrandColor.shared.brandElement))
                .frame(height: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/)

            Text("No tasks in here")
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 5)

            Text("Use the + button to create one")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    EmptyTasksView()
}

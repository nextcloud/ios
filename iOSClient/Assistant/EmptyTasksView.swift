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
                .frame(height: 100)

            Text(NSLocalizedString("_no_tasks_", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 5)

            Text(NSLocalizedString("_create_task_subtitle_", comment: ""))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    EmptyTasksView()
}

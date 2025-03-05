//
//  StatusInfo.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 18.02.25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

struct StatusInfo: View {
    let task: AssistantTask
    var showStatusText = false

    var body: some View {
        HStack {
            Label(
                title: {
                    let text = (showStatusText && task.statusInfo.stringKey != "_assistant_task_completed_") ? "(\(NSLocalizedString(task.statusInfo.stringKey, comment: "")))" : ""

                    Text("\(task.statusDate) \(text)")
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
}

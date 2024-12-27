//
//  SwiftUIView.swift
//  Nextcloud
//
//  Created by Milen on 21.05.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import NextcloudKit
import SwiftUI

struct NCLoginPoll: View {
    let loginFlowV2Login: String

    @ObservedObject var model: NCLoginPollModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text(NSLocalizedString("_poll_desc_", comment: ""))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
                .padding()

            HStack {
                Button(NSLocalizedString("_cancel_", comment: "")) {
                    dismiss()
                }
                .disabled(model.isLoading)
                .buttonStyle(.bordered)
                .tint(.white)

                Button(NSLocalizedString("_retry_", comment: "")) {
                    model.openLoginInBrowser(loginFlowV2Login: loginFlowV2Login)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color(NCBrandColor.shared.customer))
                .tint(.white)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NCBrandColor.shared.customer))
        .onAppear {
            if !isRunningForPreviews {
                model.openLoginInBrowser(loginFlowV2Login: loginFlowV2Login)
            }
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    NCLoginPoll(loginFlowV2Login: "", model: NCLoginPollModel())
}

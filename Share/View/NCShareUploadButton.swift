// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@MainActor
struct NCShareUploadButton: View {
    let fileCount: Int
    var isPreparing = false
    var title: String?
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isPreparing {
                    ProgressView()
                        .tint(.white)
                    Text(NSLocalizedString("_share_conflict_checking_", comment: ""))
                } else {
                    Text(title ?? String.localizedStringWithFormat(NSLocalizedString("_share_upload_to_", comment: ""), fileCount))
                }
            }
            .lineLimit(2)
            .truncationMode(.middle)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .padding(.horizontal, 16)
    }
}

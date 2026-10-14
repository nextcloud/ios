// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

/// Full-screen error state with a retry action.
struct NCCollectivesErrorView: View {
    let error: NKError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("_collectives_load_error_", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.errorDescription)
        } actions: {
            Button("_retry_", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

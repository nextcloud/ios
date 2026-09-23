// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A reusable SwiftUI sheet that presents the NCMedia selection UI
/// and returns the selected file identifiers.
struct MediaSelectionSheet: View {
    private unowned let controller: NCMainTabBarController

    // MARK: - Callbacks
    let onCancel: () -> Void
    let onDone: (_ selectedFiles: [String]) -> Void

    // MARK: - State
    @State private var mediaVC: NCMedia?

    init(controller: NCMainTabBarController, onCancel: @escaping () -> Void, onDone: @escaping (_ selectedFiles: [String]) -> Void) {
        self.controller = controller
        self.onCancel = onCancel
        self.onDone = onDone
    }

    var body: some View {
        NavigationView {
            NCMediaViewRepresentable(controller: controller, ncMedia: $mediaVC)
            .navigationTitle(NSLocalizedString("_albums_photo_selection_sheet_title_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(
                        NSLocalizedString("_cancel_", comment: "")
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onDone(mediaVC?.fileSelect ?? [])
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(
                        NSLocalizedString("_done_", comment: "")
                    )
                    .disabled(mediaVC == nil)
                }
            }
        }
    }
}

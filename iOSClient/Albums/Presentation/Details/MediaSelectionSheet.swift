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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("_albums_photo_selection_sheet_back_btn_", comment: "")) {
                        onCancel()
                    }
                    .foregroundColor(Color(NCBrandColor.shared.getElement(account: controller.account)))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("_albums_photo_selection_sheet_done_btn_", comment: "")) {
                        onDone(mediaVC?.fileSelect ?? [])
                    }
                    .foregroundColor(Color(NCBrandColor.shared.getElement(account: controller.account)))
                    .disabled(mediaVC == nil)
                    .opacity(mediaVC == nil ? 0.5 : 1.0)
                }
            }
        }
    }
}

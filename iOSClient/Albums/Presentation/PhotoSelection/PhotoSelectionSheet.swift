// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct PhotoSelectionSheet: View {
    private unowned let controller: NCMainTabBarController
    let onPhotosSelected: ([String]) -> Void

    @State private var mediaVC: NCMedia?

    init(controller: NCMainTabBarController, onPhotosSelected: @escaping ([String]) -> Void) {
        self.controller = controller
        self.onPhotosSelected = onPhotosSelected
    }

    var body: some View {
        NavigationView {
            VStack {
                NCMediaViewRepresentable(controller: controller, ncMedia: $mediaVC)
                    .frame(maxHeight: .infinity)
            }
            .navigationTitle(NSLocalizedString("_albums_photo_selection_sheet_title_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onPhotosSelected([])
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(
                        NSLocalizedString("_albums_photo_selection_sheet_back_btn_", comment: "")
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onPhotosSelected(mediaVC?.fileSelect ?? [])
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(
                        NSLocalizedString("_albums_photo_selection_sheet_done_btn_", comment: "")
                    )
                    .disabled(mediaVC == nil)
                }
            }
        }
    }
}

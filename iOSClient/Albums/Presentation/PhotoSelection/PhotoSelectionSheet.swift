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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("_albums_photo_selection_sheet_back_btn_", comment: "")) {
                        onPhotosSelected([])
                    }
                    .foregroundColor(Color(NCBrandColor.shared.getElement(account: controller.account)))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("_albums_photo_selection_sheet_done_btn_", comment: "")) {
                        onPhotosSelected(mediaVC?.fileSelect ?? [])
                    }
                    .foregroundColor(Color(NCBrandColor.shared.getElement(account: controller.account)))
                    .disabled(mediaVC == nil)
                }

            }
        }
    }
}

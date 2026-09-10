// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct PhotoSelectionSheet: View {
    let onPhotosSelected: ([String]) -> Void
    @State private var mediaVC: NCMedia?

    var body: some View {
        NavigationView {
            VStack {
                NCMediaViewRepresentable(ncMedia: $mediaVC)
                    .frame(maxHeight: .infinity)
            }
            .navigationTitle(NSLocalizedString("_albums_photo_selection_sheet_title_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("_albums_photo_selection_sheet_back_btn_", comment: "")) {
                        onPhotosSelected([])
                    }
                    .foregroundColor(Color(NCBrandColor.shared.customer))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("_albums_photo_selection_sheet_done_btn_", comment: "")) {
                        onPhotosSelected(mediaVC?.fileSelect ?? [])
                    }
                    .foregroundColor(Color(NCBrandColor.shared.customer))
                    .disabled(mediaVC == nil)
                }

            }
        }
    }
}

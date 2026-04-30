//
//  PhotoSelectionSheet.swift
//  Nextcloud
//
//  Created by Dhanesh on 04/09/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct PhotoSelectionSheet: View {
    let onPhotosSelected: ([String]) -> Void
    @State private var mediaVC: NCMedia?
    @State private var selectedPhotosCount: Int = 0

    var body: some View {
        NavigationView {
            NCMediaViewRepresentable(
                ncMedia: $mediaVC,
                selectedCount: $selectedPhotosCount,
                isSelectionContext: true
            )
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
                }

            }
            .onChange(of: mediaVC?.fileSelect ?? []) { oldValue, newValue in
                selectedPhotosCount = newValue.count
            }
        }
    }
}


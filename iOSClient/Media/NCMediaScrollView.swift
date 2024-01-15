//
//  NCMediaScrollView.swift
//  Nextcloud
//
//  Created by Milen on 13.10.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import Queuer

struct NCMediaScrollView: View, Equatable {
    static func == (lhs: NCMediaScrollView, rhs: NCMediaScrollView) -> Bool {
        return lhs.metadatas == rhs.metadatas
    }

    @State private var orientation = UIDevice.current.orientation.isLandscapeHardCheck
    @State private var hasRotated = false

    var metadatas: [[tableMetadata]]
    @Binding var title: String
    @Binding var shouldShowPaginationLoading: Bool
    @Binding var topMostVisibleMetadataDate: Date
    @Binding var bottomMostVisibleMetadataDate: Date

    let onCellSelected: (ScaledThumbnail, Bool) -> Void
    let onCellContextMenuItemSelected: (ScaledThumbnail, ContextMenuSelection) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(metadatas, id: \.self) { rowMetadatas in
                    NCMediaRow(metadatas: rowMetadatas) { tappedThumbnail, isSelected in
                        onCellSelected(tappedThumbnail, isSelected)
                    } onCellContextMenuItemSelected: { thumbnail, selection in
                        onCellContextMenuItemSelected(thumbnail, selection)
                    }
                    // NOTE: This only works properly on device. On simulator, for some reason, these get called way too early or way too late.
                    .onAppear {
                        if hasRotated { return }
                        guard let date = rowMetadatas.first?.date as? Date else { return }
                        bottomMostVisibleMetadataDate = date
                        title = NCUtility().getTitleFromDate(max(topMostVisibleMetadataDate, bottomMostVisibleMetadataDate))
                    }
                    .onDisappear {
                        if hasRotated { return }
                        guard let date = rowMetadatas.last?.date as? Date else { return }
                        topMostVisibleMetadataDate = date
                        title = NCUtility().getTitleFromDate(max(topMostVisibleMetadataDate, bottomMostVisibleMetadataDate))
                    }
                }

                if !metadatas.isEmpty, shouldShowPaginationLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
            .onRotate { orientation in
                if self.orientation == orientation.isLandscapeHardCheck { return }

                self.orientation = orientation.isLandscapeHardCheck
                hasRotated = true
                title = NSLocalizedString("_media_", comment: "")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    hasRotated = false
                }
            }
            .padding(.top, 70)
            .padding(.bottom, 40)
        }
    }
}

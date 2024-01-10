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

    var metadatas: [[tableMetadata]]
    @Binding var isInSelectMode: Bool
    @Binding var selectedMetadatas: [tableMetadata]
    @Binding var title: String
    @Binding var shouldShowPaginationLoading: Bool
    @Binding var topMostVisibleMetadataDate: Date
    @Binding var bottomMostVisibleMetadataDate: Date

    let proxy: ScrollViewProxy

    let onCellSelected: (ScaledThumbnail, Bool) -> Void
    let onCellContextMenuItemSelected: (ScaledThumbnail, ContextMenuSelection) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(metadatas, id: \.self) { rowMetadatas in
                    NCMediaRow(metadatas: rowMetadatas, isInSelectMode: $isInSelectMode) { tappedThumbnail, isSelected in
                        onCellSelected(tappedThumbnail, isSelected)
                    } onCellContextMenuItemSelected: { thumbnail, selection in
                        onCellContextMenuItemSelected(thumbnail, selection)
                    }
                    // NOTE: This only works properly on device. On simulator, for some reason, these get called way too early or way too late.
                    .onAppear {
                        guard let date = rowMetadatas.first?.date as? Date else { return }
                        bottomMostVisibleMetadataDate = date
                        title = NCUtility().getTitleFromDate(max(topMostVisibleMetadataDate, bottomMostVisibleMetadataDate))
                    }
                    .onDisappear {
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
            .background(GeometryReader { proxy in
                let offset = proxy.frame(in: .named("scroll")).minY
                Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: offset)
            })
            .padding(.top, 70)
            .padding(.bottom, 40)
        }
    }
}

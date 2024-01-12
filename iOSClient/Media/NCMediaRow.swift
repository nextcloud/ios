//
//  NCMediaRow.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import PreviewSnapshots
import Queuer

struct NCMediaRow: View {
    let metadatas: [tableMetadata]

    @Binding var selectedMetadatas: [tableMetadata]
    @Binding var isInSelectMode: Bool

    let onCellSelected: (ScaledThumbnail, Bool) -> Void
    let onCellContextMenuItemSelected: (ScaledThumbnail, ContextMenuSelection) -> Void

    @StateObject private var vm = NCMediaRowViewModel()
    private let spacing: CGFloat = 2

    var body: some View {
//        let _ = Self._printChanges()

        HStack(spacing: spacing) {
            if vm.rowData.scaledThumbnails.isEmpty {
                ForEach(metadatas, id: \.ocId) { metadata in
                    NCMediaLoadingCell(itemsInRow: metadatas.count, metadata: metadata, rowSize: UIScreen.main.bounds.width, spacing: spacing)
                }
            } else {
                ForEach(vm.rowData.scaledThumbnails, id: \.metadata.ocId) { thumbnail in
                    NCMediaCell(thumbnail: thumbnail, shrinkRatio: vm.rowData.shrinkRatio, isInSelectMode: $isInSelectMode, isSelected: selectedMetadatas.contains(where: {$0 == thumbnail.metadata}), onSelected: onCellSelected, onContextMenuItemSelected: onCellContextMenuItemSelected, isFavorite: thumbnail.metadata.favorite)
                }
            }
        }
        .onFirstAppear {
            vm.configure(metadatas: metadatas)
        }
        .onAppear {
            vm.downloadThumbnails(rowWidth: UIScreen.main.bounds.width, spacing: spacing)
        }
        .onDisappear {
            vm.cancelDownloadingThumbnails()
        }
    }
}

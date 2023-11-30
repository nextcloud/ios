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

    @Binding var isInSelectMode: Bool
//    let queuer: Queuer
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
                    NCMediaCell(thumbnail: thumbnail, shrinkRatio: vm.rowData.shrinkRatio, isInSelectMode: $isInSelectMode, onSelected: onCellSelected, onContextMenuItemSelected: onCellContextMenuItemSelected, isFavorite: thumbnail.metadata.favorite)
                }
            }
        }
        .onFirstAppear {
            vm.configure(metadatas: metadatas)
            vm.downloadThumbnails(rowWidth: UIScreen.main.bounds.width, spacing: spacing)
        }
        .onDisappear {
            vm.cancelDownloadingThumbnails()
        }
//        .onRotate { _ in
//            vm.configure(metadatas: metadatas)
//            vm.downloadThumbnails(rowWidth: UIScreen.main.bounds.width, spacing: spacing)
//        }
    }
}

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

    let onCellSelected: (ScaledThumbnail, Bool) -> Void
    let onCellContextMenuItemSelected: (ScaledThumbnail, ContextMenuSelection) -> Void

    @StateObject private var vm = NCMediaRowViewModel()
    private let spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            if vm.rowData.scaledThumbnails.isEmpty {
                ForEach(metadatas, id: \.ocId) { metadata in
                    NCMediaLoadingCell(itemsInRow: metadatas.count, metadata: metadata, rowSize: UIScreen.main.bounds.width, spacing: spacing)
                }
            } else {
                ForEach(vm.rowData.scaledThumbnails, id: \.metadata.ocId) { thumbnail in
                    NCMediaCell(thumbnail: thumbnail, shrinkRatio: vm.rowData.shrinkRatio, isFavorite: thumbnail.metadata.favorite, onSelected: onCellSelected, onContextMenuItemSelected: onCellContextMenuItemSelected)
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

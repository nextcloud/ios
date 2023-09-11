//
//  NCMediaRow.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import PreviewSnapshots

struct NCMediaRow: View {
    let metadatas: [tableMetadata]
    let geometryProxy: GeometryProxy
    @Binding var title: String

    @StateObject private var viewModel = NCMediaRowViewModel()
    private let spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            if viewModel.rowData.scaledThumbnails.isEmpty {
                ProgressView()
            } else {
                ForEach(viewModel.rowData.scaledThumbnails, id: \.self) { thumbnail in
                    NCMediaCellView(thumbnail: thumbnail, shrinkRatio: viewModel.rowData.shrinkRatio, outerProxy: geometryProxy, title: $title)
                }
            }
        }
        .onAppear {
            viewModel.configure(metadatas: metadatas)
            viewModel.downloadThumbnails(rowWidth: geometryProxy.size.width, spacing: spacing)
        }
    }
}


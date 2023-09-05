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
    @StateObject private var viewModel = NCMediaRowViewModel()

    var body: some View {
        HStack() {
            if viewModel.rowData.scaledThumbnails.isEmpty {
                ProgressView()
            } else {
                ForEach(viewModel.rowData.scaledThumbnails, id: \.self) { thumbnail in
                    NCMediaCellView(thumbnail: thumbnail, shrinkRatio: viewModel.rowData.shrinkRatio)
                }
            }
        }
        .onAppear {
            viewModel.configure(metadatas: metadatas)
            viewModel.downloadThumbnails()
        }
    }
}


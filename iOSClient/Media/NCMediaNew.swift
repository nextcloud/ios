//
//  NCMediaNew.swift
//  Nextcloud
//
//  Created by Milen on 25.08.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import PreviewSnapshots
import NextcloudKit
import FlowGrid

class NCMediaUIHostingController: UIHostingController<NCMediaNew> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: NCMediaNew())
    }
}

struct NCMediaNew: View {
    @StateObject private var viewModel = NCMediaViewModel()

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(viewModel.metadatas.chunked(into: 2), id: \.self) { rowMetadatas in
                        NCMediaRow(metadatas: rowMetadatas)
                    }
                }
            }
        }
    }
}

struct RowData {
    var scaledThumbnails: [ScaledThumbnail] = []
    var shrinkRatio: CGFloat = 0
}

struct ScaledThumbnail: Hashable {
    let image: UIImage
    var scaledSize: CGSize = .zero
    let metadata: tableMetadata

    func hash(into hasher: inout Hasher) {
        hasher.combine(image)
    }
}

struct NCMediaNew_Previews: PreviewProvider {
    static var previews: some View {
        snapshots.previews.previewLayout(.sizeThatFits)
    }

    static var snapshots: PreviewSnapshots<String> {
        PreviewSnapshots(
            configurations: [
                .init(name: NCGlobal.shared.defaultSnapshotConfiguration, state: "")
            ],
            configure: { _ in
                NCMediaNew()
            })
    }
}

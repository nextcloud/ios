//
//  NCMediaRow.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import PreviewSnapshots

//struct NCMediaRow: View {
//    let metadatas: [tableMetadata]
//    @StateObject private var viewModel = MediaCellViewModel()
//
//    var body: some View {
//        HStack() {
//            if viewModel.rowData.scaledThumbnails.isEmpty {
//                ProgressView()
//            } else {
//                ForEach(viewModel.rowData.scaledThumbnails, id: \.self) { thumbnail in
//                    MediaCellView(thumbnail: thumbnail, shrinkRatio: viewModel.rowData.shrinkRatio)
//                }
//            }
//        }
//        .onAppear {
//            viewModel.configure(metadatas: metadatas)
//            viewModel.downloadThumbnails()
//        }
//    }
//}
//
//struct MediaCellView: View {
//    let thumbnail: ScaledThumbnail
//    let shrinkRatio: CGFloat
////    let thumbnail: UIImage
////    let metadata: tableMetadata
////    @StateObject private var viewModel = MediaCellViewModel()
//
//    var body: some View {
//        Image(uiImage: thumbnail.image)
//            .resizable()
////            .scaledToFill()
//            .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))
//
////        let wtf = CGFloat(metadata.width) * shrinkRatio
////        let _ = print(viewModel.thumbnail.size.width)
////        let _ = print(viewModel.thumbnail.size.height)
//    }
//}
//
//struct NCMediaRow_Previews: PreviewProvider {
//    static var previews: some View {
//        snapshots.previews.previewLayout(.sizeThatFits)
//    }
//
//    static var snapshots: PreviewSnapshots<String> {
//        PreviewSnapshots(
//            configurations: [
//                .init(name: NCGlobal.shared.defaultSnapshotConfiguration, state: "")
//            ],
//            configure: { _ in
//                NCMediaRow()
//            })
//    }
//}


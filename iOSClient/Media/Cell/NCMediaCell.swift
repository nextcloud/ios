//
//  NCMediaCellView.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import VisibilityTrackingScrollView
import Shimmer
import NextcloudKit

struct NCMediaCell: View {
    let thumbnail: ScaledThumbnail
    let shrinkRatio: CGFloat

    let onTap: (ScaledThumbnail) -> Void

    var body: some View {
        let image = Image(uiImage: thumbnail.image)
            .resizable()
            .trackVisibility(id: CCUtility.getTitleSectionDate(thumbnail.metadata.date as Date) ?? "")
            .contextMenu(ContextMenu(menuItems: {
                Text("Menu Item 1")
                Text("Menu Item 2")
                Text("Menu Item 3")
            }))

        ZStack(alignment: .bottomLeading) {
            ZStack(alignment: .center) {
                if thumbnail.isDefaultImage {
                    image
                        .foregroundColor(Color(uiColor: .systemGray4))
                        .scaledToFit()
                        .frame(width: 40)
                } else {
                    image
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if thumbnail.metadata.isVideo {
                Image(systemName: "play.fill")
                    .resizable()
                    .foregroundColor(Color(uiColor: .systemGray4))
                    .scaledToFit()
                    .frame(width: 20)
                    .padding([.leading, .bottom], 10)
            }
        }
        .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))
        .background(Color(uiColor: .systemGray6))
        .onTapGesture {
            onTap(thumbnail)
        }
    }
}

struct NCMediaCell_Previews: PreviewProvider {
    static var previews: some View {
        let mockMetadata = tableMetadata()

        NCMediaCell(thumbnail: .init(image: UIImage(systemName: "video.fill")!, metadata: mockMetadata), shrinkRatio: 1, onTap: { _ in })
    }
}

struct NCMediaLoadingCell: View {
    let itemsInRow: Int
    let metadata: tableMetadata
    let geometryProxy: GeometryProxy
    let spacing: CGFloat

    let gradient = Gradient(colors: [
        .black.opacity(0.4),
        .black.opacity(0.7),
        .black.opacity(0.4)
    ])

    var body: some View {
        ZStack {
            Image(uiImage: UIImage())
                .resizable()
                .trackVisibility(id: CCUtility.getTitleSectionDate(metadata.date as Date) ?? "")// TODO: Fix spacing
                .frame(width: (geometryProxy.size.width - spacing) / CGFloat(itemsInRow), height: 130)
                .redacted(reason: .placeholder)
                .shimmering(gradient: gradient, bandSize: 0.7)
        }
    }
}

struct NCMediaLoadingCell_Previews: PreviewProvider {
    static var previews: some View {
        let mockMetadata = tableMetadata()

        GeometryReader { proxy in
            NCMediaLoadingCell(itemsInRow: 1, metadata: tableMetadata(), geometryProxy: proxy, spacing: 2)
        }
    }
}

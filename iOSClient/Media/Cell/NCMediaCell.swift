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

struct NCMediaCell: View {
    let thumbnail: ScaledThumbnail
    let shrinkRatio: CGFloat

    var body: some View {
        var image = Image(uiImage: thumbnail.image)
            .resizable()
            .trackVisibility(id: CCUtility.getTitleSectionDate(thumbnail.metadata.date as Date) ?? "")

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
                    .padding(.leading, 10)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))
        .background(Color(uiColor: .systemGray6))
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

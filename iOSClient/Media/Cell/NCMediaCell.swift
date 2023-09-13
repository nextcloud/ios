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
        ZStack {
            Image(uiImage: thumbnail.image)
                .resizable()
                .trackVisibility(id: CCUtility.getTitleSectionDate(thumbnail.metadata.date as Date) ?? "")
                .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))

//            Text(CCUtility.getTitleSectionDate(thumbnail.metadata.date as Date)).lineLimit(1).foregroundColor(.white)
        }
    }
}

struct NCMediaLoadingCell: View {
    let height: CGFloat
    let itemsInRow: Int
    let metadata: tableMetadata

    let gradient = Gradient(colors: [
        .black.opacity(0.4),
        .black.opacity(0.7),
        .black.opacity(0.4)
    ])

    var body: some View {
        ZStack {
            Image(uiImage: UIImage())
                .resizable()
                .trackVisibility(id: CCUtility.getTitleSectionDate(metadata.date as Date) ?? "")
                .frame(width: UIScreen.main.bounds.width / CGFloat(itemsInRow), height: 130)
                .redacted(reason: .placeholder)
                .shimmering(gradient: gradient, bandSize: 0.7)
        }
    }
}

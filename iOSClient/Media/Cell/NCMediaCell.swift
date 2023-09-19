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
    @Binding var isInSelectMode: Bool
    let onTap: (ScaledThumbnail, Bool) -> Void
    @State private var isTappedInSelectMode = false

    var body: some View {
        let image = Image(uiImage: thumbnail.image)
            .resizable()
            .trackVisibility(id: CCUtility.getTitleSectionDate(thumbnail.metadata.date as Date) ?? "")
            .contextMenu(ContextMenu(menuItems: {
                Text("Menu Item 1")
                Text("Menu Item 2")
                Text("Menu Item 3")
            }))

        ZStack(alignment: .center) {
//                NavigationLink(destination: NCViewerMediaPageController(metadatas: [thumbnail.metadata], selectedMetadata: thumbnail.metadata)) {
                    if thumbnail.isDefaultImage {
                        image
                            .foregroundColor(Color(uiColor: .systemGray4))
                            .scaledToFit()
                            .frame(width: 40)
                    } else {
                        image
                    }
//                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomLeading) {
                if thumbnail.metadata.isVideo, !thumbnail.isDefaultImage {
                    Image(systemName: "play.fill")
                        .resizable()
                        .foregroundColor(Color(uiColor: .systemGray4))
                        .scaledToFit()
                        .frame(width: 20)
                        .padding([.leading, .bottom], 10)
                }
            }
            .overlay {
                if isInSelectMode, isTappedInSelectMode {
                    Color.black.opacity(0.6).frame(maxWidth: .infinity)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isInSelectMode, isTappedInSelectMode {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .foregroundColor(.blue)
                        .background(.white)
                        .clipShape(Circle())
                        .scaledToFit()
                        .frame(width: 20)
                        .padding([.trailing, .bottom], 10)
                }
            }
            .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))
            .background(Color(uiColor: .systemGray6))
            .onTapGesture {
                if isInSelectMode { isTappedInSelectMode.toggle() }
                onTap(thumbnail, isTappedInSelectMode)
            }
            .onChange(of: isInSelectMode) { newValue in
                isTappedInSelectMode = !newValue
            }
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

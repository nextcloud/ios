//
//  NCMediaCellView.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import VisibilityTrackingScrollView

struct NCMediaCell: View {
    let thumbnail: ScaledThumbnail
    let shrinkRatio: CGFloat

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image(uiImage: thumbnail.image)
                    .resizable()
            }
            .trackVisibility(id: CCUtility.getTitleSectionDate(thumbnail.metadata.date as Date) ?? "")
            .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))

//            Text(thumbnail.metadata.fileName).lineLimit(1).foregroundColor(.white)
        }
    }
}

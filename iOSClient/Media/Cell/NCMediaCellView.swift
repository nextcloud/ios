//
//  NCMediaCellView.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct NCMediaCellView: View {
    let thumbnail: ScaledThumbnail
    let shrinkRatio: CGFloat

    var body: some View {
        Image(uiImage: thumbnail.image)
            .resizable()
            .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))
    }
}

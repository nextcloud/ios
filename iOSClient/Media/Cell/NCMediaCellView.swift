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
    let outerProxy: GeometryProxy
    @Binding var title: String

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: thumbnail.image)
                .resizable()
            //                .scaledToFit()
            //                .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))
                .onChange(of: geometry.frame(in: .named(NCMediaNew.scrollViewCoordinateSpace))) { rect in
                    if isInView(innerRect: rect, isIn: outerProxy) {
                        print(thumbnail.metadata.fileName)
                        title = thumbnail.metadata.fileName
                    }
                }
        }
        .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))
    }

    private func isInView(innerRect:CGRect, isIn outerProxy:GeometryProxy) -> Bool {
        let innerOrigin = innerRect.origin.x
        let imageWidth = innerRect.width
        let scrollOrigin = outerProxy.frame(in: .global).origin.x
        let scrollWidth = outerProxy.size.width
        if innerOrigin + imageWidth < scrollOrigin + scrollWidth && innerOrigin + imageWidth > scrollOrigin ||
            innerOrigin + imageWidth > scrollOrigin && innerOrigin < scrollOrigin + scrollWidth {
            return true
        }
        return false
    }
}

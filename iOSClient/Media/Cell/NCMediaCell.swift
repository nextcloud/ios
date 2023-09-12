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
    let outerProxy: GeometryProxy
    @Binding var title: String
//    @State private var visibleIndex: Set<Int> = [0,1]
    @State private var visibleMetadata: IsCellVisiblePreferenceKey.PreferenceValue? = nil


    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image(uiImage: thumbnail.image)
                    .resizable()
                //                .scaledToFit()
                //                .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))
//                    .onChange(of: geometry.frame(in: .named(NCMediaNew.scrollViewCoordinateSpace))) { rect in
//                        if isInView(innerRect: rect, isIn: outerProxy) {
//                            visibleMetadata = .init(isVisible: true, metadata: thumbnail.metadata)
//                        } else {
//                            visibleMetadata = .init(isVisible: false, metadata: thumbnail.metadata)
//                        }
//                    }
//                    .preference(key: IsCellVisiblePreferenceKey.self, value: visibleMetadata)
            }
            .trackVisibility(id: CCUtility.getTitleSectionDate(thumbnail.metadata.date as Date) ?? "")
            .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))

            Text(thumbnail.metadata.fileName).lineLimit(1).foregroundColor(.white)
        }
    }
}

struct IsCellVisiblePreferenceKey: PreferenceKey {
    struct PreferenceValue: Equatable {
        let isVisible: Bool
        let metadata: tableMetadata
    }

    typealias Value = PreferenceValue?
    static var defaultValue: Value = nil

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value ?? nextValue()
    }
}

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
    @State var columns = 2
    @State var title = ""

    public static let scrollViewCoordinateSpace = "scrollView"

    var body: some View {
        GeometryReader { outerProxy in
            ZStack(alignment: .top) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.metadatas.chunked(into: columns), id: \.self) { rowMetadatas in
                                NCMediaRow(metadatas: rowMetadatas, geometryProxy: outerProxy, title: $title)
//                                    .onChange(of: geometry.frame(in: .local)) { rect in
//                                        if isInView(innerRect: rect, isIn: outerProxy) {
//                                            print("WOW")
//                                        }
//                                    }
                        }
                    }
                }.coordinateSpace(name: NCMediaNew.scrollViewCoordinateSpace)

                HStack(content: {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                })
                .frame(maxWidth: .infinity)
                .background(LinearGradient(gradient: Gradient(colors: [.black.opacity(0.8), .black.opacity(0.0)]), startPoint: .top, endPoint: .bottom).edgesIgnoringSafeArea(.top))
            }
            .onRotate { orientation in
                if orientation.isLandscapeHardCheck {
                    columns = 6
                } else {
                    columns = 2
                }
            }
        }
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

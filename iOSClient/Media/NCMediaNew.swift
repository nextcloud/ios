//
//  NCMediaNew.swift
//  Nextcloud
//
//  Created by Milen on 25.08.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import PreviewSnapshots

class NCMediaUIHostingController: UIHostingController<NCMediaNew> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: NCMediaNew())
    }
}

struct NCMediaNew: View {
    @State private var gridColumns = Array(repeating: GridItem(.flexible(minimum: 50)), count: 2)

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: gridColumns) {
                    ForEach(0...20, id: \.self) { value in
                        GeometryReader { geo in
                            ZStack(alignment: .topTrailing) {
                                //                                AsyncImage(url: URL(string: "https://picsum.photos/id/237/536/354")) { image in
                                //                                    image
                                //                                        .resizable()
                                //                                        .frame(width: CGFloat.random(in: 20...50), height: 50)
                                //                                }
                                AsyncImage(url: URL(string: "https://picsum.photos/id/237/536/354")) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: CGFloat.random(in: 20...200), height: 50)
                            }
                        }
                        .cornerRadius(8.0)
//                                                .aspectRatio(1, contentMode: .fit)
                                                .aspectRatio(CGFloat.random(in: 1...5), contentMode: .fit)
                    }
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

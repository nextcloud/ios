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
import VisibilityTrackingScrollView

class NCMediaUIHostingController: UIHostingController<NCMediaNew> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: NCMediaNew())
    }
}

struct NCViewerMediaPageController: UIViewControllerRepresentable {
    let metadatas: [tableMetadata]
    let selectedMetadata: tableMetadata

    func makeUIViewController(context: UIViewControllerRepresentableContext<NCViewerMediaPageController>) -> UINavigationController {

        if let viewController = UIStoryboard(name: "NCViewerMediaPage", bundle: nil).instantiateInitialViewController() as? NCViewerMediaPage {
            var index = 0
            for medatasImage in metadatas {
                if medatasImage.ocId == selectedMetadata.ocId {
                    viewController.currentIndex = index
                    break
                }
                index += 1
            }
            viewController.metadatas = metadatas

            return UINavigationController(rootViewController: viewController)
        } else {
            return UINavigationController()
        }
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: UIViewControllerRepresentableContext<NCViewerMediaPageController>) {}
}

struct NCMediaNew: View {
    @StateObject private var vm = NCMediaViewModel()
    @State private var columns = 2
    @State private var title = ""
    @State private var isScrolledToTop = true
    @State private var isMediaViewControllerPresented = false
    @State private var selectedMetadata = tableMetadata()
    @State private var sort: Int = 0

    var body: some View {
        GeometryReader { outerProxy in
            ZStack(alignment: .top) {
                VisibilityTrackingScrollView(action: cellVisibilityDidChange) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(vm.metadatas.chunked(into: columns), id: \.self) { rowMetadatas in
                            NCMediaRow(metadatas: rowMetadatas, geometryProxy: outerProxy) { tappedThumbnail in
                                selectedMetadata = tappedThumbnail.metadata
                                isMediaViewControllerPresented = true
                            }
                        }

                        if vm.needsLoadingMoreItems {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .onAppear { vm.loadMoreItems() }
                                .padding(.top, 10)
                        }
                    }
                    .padding(.top, 70)
                    .padding(.bottom, 40)
                    .background(GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin)
                    })
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        withAnimation(.easeInOut) {
                            isScrolledToTop = value.y >= -10
                        }
                    }

                }
                .refreshable {
                    vm.onPullToRefresh()
                }
                .coordinateSpace(name: "scroll")

                HStack(content: {
                    HStack {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(isScrolledToTop ? .black : .white)
                        Spacer()
                        Button(action: {}, label: {
                            Text("Select")
                        })
                        Menu {
                            Section {
                                Button(action: {
                                    vm.filterClassTypeImage = !vm.filterClassTypeImage
                                    vm.filterClassTypeVideo = false
                                }, label: {
                                    Label(NSLocalizedString(vm.filterClassTypeImage ? "_media_viewimage_show_" : "_media_viewimage_hide_", comment: ""), systemImage: "photo.fill")
                                })
                                Button(action: {
                                    vm.filterClassTypeVideo = !vm.filterClassTypeVideo
                                    vm.filterClassTypeImage = false
                                }, label: {
                                    Label(NSLocalizedString(vm.filterClassTypeVideo ? "_media_viewvideo_show_" : "_media_viewvideo_hide_", comment: ""), systemImage: "video.fill")
                                })
                                Button(action: {}, label: {
                                    Label(NSLocalizedString("_select_media_folder_", comment: ""), systemImage: "folder")
                                })
                            }

                            Section {
                                Button(action: {}, label: {
                                    Label(NSLocalizedString("_play_from_files_", comment: ""), systemImage: "play.circle")
                                })
                                Button(action: {}, label: {
                                    Label(NSLocalizedString("_play_from_url_", comment: ""), systemImage: "link")
                                })
                            }

                            Picker("Sorting options", selection: $sort) {
                                Label(NSLocalizedString("_media_by_modified_date_", comment: ""), systemImage: "circle.grid.cross.up.fill").tag(0)
                                Label(NSLocalizedString("_media_by_created_date_", comment: ""), systemImage: "circle.grid.cross.down.fill").tag(1)
                                Label(NSLocalizedString("_media_by_upload_date_", comment: ""), systemImage: "circle.grid.cross.right.fill").tag(2)
                            }
                            .pickerStyle(.menu)

                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                })
                .frame(maxWidth: .infinity)
                .padding([.horizontal, .top], 10)
                .padding(.bottom, 20)
                .background(LinearGradient(gradient: Gradient(colors: isScrolledToTop ? [.clear] : [.black.opacity(0.8), .black.opacity(0.0)]), startPoint: .top, endPoint: .bottom).edgesIgnoringSafeArea(.top))
            }
        }
        .onRotate { orientation in
            if orientation.isLandscapeHardCheck {
                columns = 6
            } else {
                columns = 2
            }
        }
        .onAppear { vm.loadData() }
        .fullScreenCover(isPresented: $isMediaViewControllerPresented) {
            NCViewerMediaPageController(metadatas: vm.metadatas, selectedMetadata: selectedMetadata)
        }
    }

    func cellVisibilityDidChange(_ id: String, change: VisibilityChange, tracker: VisibilityTracker<String>) {
        DispatchQueue.main.async {
            if let date = tracker.topVisibleView, !date.isEmpty {
                title = date
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

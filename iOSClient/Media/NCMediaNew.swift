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
import Combine
@_spi(Advanced) import SwiftUIIntrospect
import Queuer

//struct Test: View {
//    var metadatas: [[tableMetadata]]
//    @EnvironmentObject var vm: NCMediaViewModel
//    @EnvironmentObject var parent: NCMediaUIKitWrapper
//    @State var isInSelectMode = true
//    @Binding var columnCountStages: [Int]
//    @Binding var columnCountStagesIndex: Int
//    @State var title: String = ""
//    internal let cache = UIImageLRUCache(countLimit: 1000)
//
//    var body: some View {
//        let _ = Self._printChanges()
//
//        ScrollView {
//            LazyVStack(alignment: .leading, spacing: 2) {
//                ForEach(metadatas, id: \.self) { rowMetadatas in
//                    Color.random.frame(width: 100, height: 100)
//                }
//                .background(GeometryReader { geometry in
//                    Color.clear
//                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin)
//                })
//            }
//        }
//        .coordinateSpace(name: "scroll")
//    }
//}

struct NCMediaNew: View {
    @StateObject private var vm = NCMediaViewModel()
    @EnvironmentObject private var parent: NCMediaUIKitWrapper
    let imageQueuer = Queuer(name: "downloadThumbnailQueue", maxConcurrentOperationCount: 10, qualityOfService: .default)
    @State private var title = "Media"
    @State private var isScrolledToTop = true
    @State private var tappedMetadata = tableMetadata()

    @State private var titleColor = Color.primary
    @State private var toolbarItemsColor = Color.blue
    @State private var toolbarColors = [Color.clear]

    @State private var showDeleteConfirmation = false
    @State private var showPlayFromURLAlert = false
    @State private var playFromUrlString = ""

    @State private var columnCountStages = [2, 3, 4]
    @State private var columnCountStagesIndex = 0
    @State private var columnCountChanged = false

    @State private var selectedMetadatas: [tableMetadata] = []
    @State private var isInSelectMode = false

    @State var offsetPublisherSubscription: AnyCancellable?

    var body: some View {
        let _ = Self._printChanges()

        ZStack(alignment: .top) {
            NCMediaScrollView(metadatas: vm.metadatas.chunked(into: columnCountStages[columnCountStagesIndex]), isInSelectMode: $isInSelectMode, selectedMetadatas: $selectedMetadatas, columnCountStages: $columnCountStages, columnCountStagesIndex: $columnCountStagesIndex, title: $title, queuer: imageQueuer)
                .equatable()
                .ignoresSafeArea(.all, edges: .horizontal)
            //                MediaScrollView(metadatas: vm.metadatas.chunked(into: columnCountStages[columnCountStagesIndex]), proxy: geometry, vm: $columnCountStages, parent: $columnCountStagesIndex, isInSelectMode: $isScrolledToTop, selectedMetadatas: $selectedMetadatas, isInSelectMode: $isInSelectMode)
            //            Test(metadatas: vm.metadatas.chunked(into: columnCountStages[columnCountStagesIndex]), columnCountStages: $columnCountStages, columnCountStagesIndex: $columnCountStagesIndex)
                .environmentObject(vm)
            //                    .environmentObject(parent)
            //                    .onPreferenceChange(TitlePreferenceKey.self) { value in
            //                        title = value
            //                    }
                .introspect(.scrollView, on: .iOS(.v15...)) { scrollView in
                    scrollView.refreshControl?.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.refreshControl?.topAnchor.constraint(equalTo: scrollView.superview!.topAnchor, constant: 120).isActive = true
                    scrollView.refreshControl?.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor).isActive = true

                    if offsetPublisherSubscription == nil {
                        offsetPublisherSubscription = scrollView.publisher(for: \.contentOffset)
                            .sink { offset in
                                DispatchQueue.main.async {
                                    isScrolledToTop = offset.y <= 0
                                }
                            }
                    }
                }

            HStack(content: {
                HStack {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(titleColor)

                    Spacer()

                    Button(action: {
                        isInSelectMode.toggle()
                    }, label: {
                        Text(NSLocalizedString(isInSelectMode ? "_cancel_" : "_select_", comment: "")).font(.system(size: 14))
                            .foregroundStyle(toolbarItemsColor)
                    })
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .cornerRadius(.infinity)

                    if isInSelectMode, !selectedMetadatas.isEmpty {
                        ToolbarCircularButton(imageSystemName: "trash.fill", color: .red)
                            .onTapGesture {
                                showDeleteConfirmation = true
                            }
                            .confirmationDialog("", isPresented: $showDeleteConfirmation) {
                                Button(NSLocalizedString("_delete_selected_media_", comment: ""), role: .destructive) {
                                    vm.deleteMetadata(metadatas: selectedMetadatas)
                                    cancelSelection()
                                }
                            }
                    }

                    Menu {
                        if isInSelectMode, !selectedMetadatas.isEmpty {
                            Section {
                                Button {
                                    vm.copyOrMoveMetadataInApp(metadatas: selectedMetadatas)
                                    cancelSelection()
                                } label: {
                                    Label(NSLocalizedString("_move_selected_files_", comment: ""), systemImage: "arrow.up.right.square")
                                }

                                Button {
                                    vm.copyMetadata(metadatas: selectedMetadatas)
                                    cancelSelection()
                                } label: {
                                    Label(NSLocalizedString("_copy_file_", comment: ""), systemImage: "doc.on.doc")
                                }
                            }
                        } else {
                            Section {
                                Picker(NSLocalizedString("_media_view_options_", comment: ""), selection: $vm.filter) {
                                    Label(NSLocalizedString("_media_viewimage_show_", comment: ""), systemImage: "photo.fill").tag(Filter.onlyPhotos)

                                    Label(NSLocalizedString("_media_viewvideo_show_", comment: ""), systemImage: "video.fill").tag(Filter.onlyVideos)

                                    Text(NSLocalizedString("_media_show_all_", comment: "")).tag(Filter.all)
                                }.pickerStyle(.menu)

                                Button {
                                    selectMediaFolder()
                                } label: {
                                    Label(NSLocalizedString("_select_media_folder_", comment: ""), systemImage: "folder")
                                }
                            }

                            Section {
                                Button(action: {
                                    if let tabBarController = vm.appDelegate?.window?.rootViewController as? UITabBarController {
                                        NCDocumentPickerViewController(tabBarController: tabBarController, isViewerMedia: true, allowsMultipleSelection: false, viewController: parent)
                                    }
                                }, label: {
                                    Label(NSLocalizedString("_play_from_files_", comment: ""), systemImage: "play.circle")
                                })

                                Button(action: {
                                    showPlayFromURLAlert = true
                                }, label: {
                                    Label(NSLocalizedString("_play_from_url_", comment: ""), systemImage: "link")
                                })
                            }
                        }
                    } label: {
                        ToolbarCircularButton(imageSystemName: "ellipsis", color: $toolbarItemsColor)
                    }
                }
            })
            .frame(maxWidth: .infinity)
            .padding([.horizontal, .top], 10)
            .padding(.bottom, 20)
            .background(LinearGradient(gradient: Gradient(colors: toolbarColors), startPoint: .top, endPoint: .bottom).ignoresSafeArea(.all, edges: [.top, .horizontal]))
        }
        .onRotate { orientation in
            if orientation.isLandscapeHardCheck {
                columnCountStages = [4, 6, 8]
            } else {
                columnCountStages = [2, 3, 4]
            }
        }
        .onChange(of: isInSelectMode) { newValue in
            if newValue == false { selectedMetadatas.removeAll() }
        }
        .onChange(of: vm.filter) { _ in
            cancelSelection()
        }
        .onChange(of: columnCountStagesIndex) { _ in
            columnCountChanged = true
        }
        .onChange(of: isScrolledToTop) { value in
            withAnimation(.default) {
                titleColor = value ? Color.primary : .white
                toolbarItemsColor = value ? .blue : .white
                toolbarColors = value ? [.clear] : [.black.opacity(0.8), .black.opacity(0.0)]
            }
        }
        .alert("", isPresented: $showPlayFromURLAlert) {
            TextField("https://...", text: $playFromUrlString)
                .keyboardType(.URL)
                .textContentType(.URL)

            Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("_ok_", comment: "")) {
                playVideoFromUrl()
            }
        } message: {
            Text(NSLocalizedString("_valid_video_url_", comment: ""))
        }
        .gesture(
            MagnificationGesture(minimumScaleDelta: 0)
                .onChanged { scale in
                    if !columnCountChanged {
                        let newZoom = Double(columnCountStages[columnCountStagesIndex]) * 1 / scale
                        let newZoomIndex = findClosestZoomIndex(value: newZoom)
                        columnCountStagesIndex = newZoomIndex
                    }
                }
                .onEnded({ _ in
                    columnCountChanged = false
                })
        )
    }

    private func findClosestZoomIndex(value: Double) -> Int {
        let distanceArray = columnCountStages.map { abs(Double($0) - value) } // absolute difference between zoom stages and actual pinch zoom
        return distanceArray.indices.min(by: {distanceArray[$0] < distanceArray[$1]}) ?? 0 // return index of element that is "closest"
    }

    private func selectMediaFolder() {
        guard let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as? UINavigationController,
              let viewController = navigationController.topViewController as? NCSelect
        else { return }

        viewController.delegate = vm
        viewController.typeOfCommandView = .select
        viewController.type = "mediaFolder"

        parent.present(navigationController, animated: true, completion: nil)
    }

    private func playVideoFromUrl() {
        guard let metadata = vm.getMetadataFromUrl(playFromUrlString) else { return }
        NCViewer().view(viewController: parent, metadata: metadata, metadatas: [metadata], imageIcon: nil)
    }

    private func cancelSelection() {
        isInSelectMode = false
        selectedMetadatas.removeAll()
    }
}

struct ToolbarCircularButton: View {
    let imageSystemName: String
    @Binding var color: Color

    init(imageSystemName: String, color: Binding<Color>) {
        self.imageSystemName = imageSystemName
        self._color = color
    }

    init(imageSystemName: String, color: Color) {
        self.imageSystemName = imageSystemName
        self._color = .constant(color)
    }

    var body: some View {
        Image(systemName: imageSystemName)
            .resizable()
            .scaledToFit()
            .frame(width: 13, height: 12)
            .padding(5)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .foregroundColor(color)
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
                    .environmentObject(NCMediaUIKitWrapper())
            })
    }
}

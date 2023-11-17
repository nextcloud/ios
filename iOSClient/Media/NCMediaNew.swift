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

struct NCMediaNew: View {
    let downloadThumbnailQueue = Queuer(name: "downloadThumbnailQueue", maxConcurrentOperationCount: 10, qualityOfService: .background)

    @StateObject private var vm = NCMediaViewModel()
    @EnvironmentObject private var parent: NCMediaUIKitWrapper
    @State private var title = NSLocalizedString("_media_", comment: "")
    @State private var isScrolledToTop = true
    @State private var tappedMetadata = tableMetadata()

    @State private var loadingIndicatorColor = Color.gray
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

    @State private var shouldScrollToTop = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                NCMediaScrollView(metadatas: $vm.metadatas, isInSelectMode: $isInSelectMode, selectedMetadatas: $selectedMetadatas, columnCountStages: $columnCountStages, columnCountStagesIndex: $columnCountStagesIndex, shouldScrollToTop: $shouldScrollToTop, proxy: proxy, queuer: downloadThumbnailQueue) { tappedThumbnail, isSelected in
                    if isInSelectMode, isSelected {
                        selectedMetadatas.append(tappedThumbnail.metadata)
                    } else {
                        selectedMetadatas.removeAll(where: { $0.ocId == tappedThumbnail.metadata.ocId })
                    }

                    if !isInSelectMode {
                        let selectedMetadata = tappedThumbnail.metadata
                        vm.onCellTapped(metadata: selectedMetadata)
                        NCViewer().view(viewController: parent, metadata: selectedMetadata, metadatas: vm.metadatas, imageIcon: tappedThumbnail.image)
                    }
                } onCellContextMenuItemSelected: { thumbnail, selection in
                    let selectedMetadata = thumbnail.metadata

                    switch selection {
                    case .addToFavorites:
                        vm.addToFavorites(metadata: selectedMetadata)
                    case .details:
                        NCActionCenter.shared.openShare(viewController: parent, metadata: selectedMetadata, page: .activity)
                    case .openIn:
                        vm.openIn(metadata: selectedMetadata)
                    case .saveToPhotos:
                        vm.saveToPhotos(metadata: selectedMetadata)
                    case .viewInFolder:
                        vm.viewInFolder(metadata: selectedMetadata)
                    case .modify:
                        vm.modify(metadata: selectedMetadata)
                    case .delete:
                        vm.delete(metadatas: selectedMetadata)
                    }
                } onRefresh: {
                    await vm.onPullToRefresh()
                }
                .equatable()
                .ignoresSafeArea(.all, edges: .horizontal)
                .introspect(.scrollView, on: .iOS(.v15...)) { scrollView in
    //                if scrollToTop {
    ////                    scrollView.setContentOffset(.init(x: 0, y: -100), animated: true)
    //
    //                    DispatchQueue.main.async {
    //                        scrollToTop = false
    //                    }
    //                }

                    scrollView.refreshControl?.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.refreshControl?.topAnchor.constraint(equalTo: scrollView.superview!.topAnchor, constant: 120).isActive = true
                    scrollView.refreshControl?.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor).isActive = true

    //                scrollView.delegate = delegate
    //                if vm.offsetPublisherSubscription == nil {
    //                    vm.offsetPublisherSubscription = scrollView.publisher(for: \.contentOffset)
    //                        .sink { offset in
    ////                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    ////                                isScrolledToTop = offset.y <= 40
    ////                            }
    //                        }
    //                }
                }.scrollStatusByIntrospect(isScrolledToTop: $isScrolledToTop)
            }


            HStack(content: {
                HStack {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(titleColor)

                    Spacer()

                    if vm.isLoadingMetadata {
                        ProgressView()
                            .tint(loadingIndicatorColor)
                            .padding(.horizontal, 6)
                    }

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
            .background(LinearGradient(gradient: Gradient(colors: toolbarColors), startPoint: .top, endPoint: .bottom)
                .padding(.bottom, -50)
                .ignoresSafeArea(.all, edges: [.all])
            )

            Button {
                shouldScrollToTop = true
            } label: {
                Label(NSLocalizedString("_new_media_", comment: ""), systemImage: "arrow.up")
            }
            .foregroundColor(.white)
//            .padding(.top, 20)
            .padding(10)
            .background(.blue)
            .clipShape(Capsule())
            .shadow(radius: 5)
            .offset(.init(width: 0, height: 50))
//            .buttonStyle(.bordered)

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
                loadingIndicatorColor = value ? Color.gray : .white
                toolbarItemsColor = value ? .blue : .white
                toolbarColors = value ? [.clear] : [Color.black.opacity(0.8), Color.black.opacity(0.4), .clear]
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

final class ScrollDelegate: NSObject, UITableViewDelegate, UIScrollViewDelegate {
//    var isScrolling: Binding<Bool>?
    var isScrolledToTop: Binding<Bool>?

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.isScrolledToTop?.wrappedValue = scrollView.contentOffset.y <= -20
        }
//        if let isScrolling = isScrolling?.wrappedValue,!isScrolling {
//            self.isScrolling?.wrappedValue = true
//        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//        if let isScrolling = isScrolling?.wrappedValue, isScrolling {
//            self.isScrolling?.wrappedValue = false
//        }
    }
//    // When the user slowly drags the scrollable control, decelerate is false after the user releases their finger, so the scrollViewDidEndDecelerating method is not called.
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
//            if let isScrolling = isScrolling?.wrappedValue, isScrolling {
//                self.isScrolling?.wrappedValue = false
//            }
        }
    }

//    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
//        if let isScrolledToTop = isScrolledToTop?.wrappedValue {
//            self.isScrolledToTop?.wrappedValue = isScrolledToTop
//        }
//    }
}

extension View {
    func scrollStatusByIntrospect(isScrolledToTop: Binding<Bool>) -> some View {
        modifier(ScrollStatusByIntrospectModifier(isScrolledToTop: isScrolledToTop))
    }
}

struct ScrollStatusByIntrospectModifier: ViewModifier {
    @State var delegate = ScrollDelegate()
    @Binding var isScrolledToTop: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                self.delegate.isScrolledToTop = $isScrolledToTop
            }
            .introspect(.scrollView, on: .iOS(.v15...)) { scrollView in
                scrollView.delegate = delegate
            }
    }
}

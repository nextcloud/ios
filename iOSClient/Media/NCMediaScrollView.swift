//
//  NCMediaScrollView.swift
//  Nextcloud
//
//  Created by Milen on 13.10.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import Queuer

struct NCMediaScrollView: View, Equatable {
    static func == (lhs: NCMediaScrollView, rhs: NCMediaScrollView) -> Bool {
        return lhs.metadatas == rhs.metadatas
    }

    var metadatas: [[tableMetadata]]
    @EnvironmentObject var vm: NCMediaViewModel
    @EnvironmentObject var parent: NCMediaUIKitWrapper
    @Binding var isInSelectMode: Bool
    @Binding var selectedMetadatas: [tableMetadata]
    @Binding var columnCountStages: [Int]
    @Binding var columnCountStagesIndex: Int
    @Binding var title: String

    let queuer: Queuer

    var body: some View {
        let _ = Self._printChanges()

        ScrollView {
            //            Spacer(minLength: 50).listRowSeparator(.hidden)

            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(metadatas, id: \.self) { rowMetadatas in
                    NCMediaRow(metadatas: rowMetadatas, isInSelectMode: $isInSelectMode, queuer: queuer) { tappedThumbnail, isSelected in
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
                    }
                    .equatable()
                    .onAppear {
                        //                        title = CCUtility.getTitleSectionDate(rowMetadatas.first?.date as? Date) ?? ""
                    }
                    //                .listRowSeparator(.hidden)
                    //                .listRowSpacing(0)
                    //                .listRowInsets(.init(top: 2, leading: 0, bottom: 0, trailing: 0))
                }

                // TODO: 3. Here we load old media (happens immediately since progress view appears in the beginning, should fix)
                if vm.needsLoadingMoreItems {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .onAppear { vm.loadMoreItems() }
                        .padding(.top, 10)
                }

                //                Spacer(minLength: 40).listRowSeparator(.hidden)
            }.background(GeometryReader { geometry in
                Color.clear
                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin)
            })
            //            .listStyle(.plain)
            .padding(.top, 70)
            .padding(.bottom, 40)
            //        }
            .coordinateSpace(name: "scroll")
            //        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            //            isScrolledToTop = value.y >= 40
            //        }
            // Not possible to move the refresh control view via SwiftUI, so we have to introspect the internal UIKit views to move it.
            // TODO: Maybe .contentMargins() will resolve this but it's iOS 17+
            //        .introspect(.scrollView, on: .iOS(.v15...)) { scrollView in
            //            scrollView.refreshControl?.translatesAutoresizingMaskIntoConstraints = false
            //            scrollView.refreshControl?.topAnchor.constraint(equalTo: scrollView.superview!.topAnchor, constant: 120).isActive = true
            //            scrollView.refreshControl?.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor).isActive = true
            //
            //            if offsetPublisherSubscription == nil {
            //                                    offsetPublisherSubscription = scrollView.publisher(for: \.contentOffset)
            //                                        .sink { offset in
            //                                            isScrolledToTop = offset.y <= 10
            //
            ////                                            withAnimation(.easeInOut) {
            ////                                                titleColor = isScrolledToTop ? Color.primary : .white
            ////                                                toolbarItemsColor = isScrolledToTop ? .blue : .white
            ////                                                toolbarColors = isScrolledToTop ? [.clear] : [.black.opacity(0.8), .black.opacity(0.0)]
            ////                                            }
            //                                        }
            //                                }
            //        }
            //        .preference(key: TitlePreferenceKey.self, value: title)
        }.refreshable {
            await vm.onPullToRefresh()
        }
    }
}

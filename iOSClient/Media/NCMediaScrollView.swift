//
//  NCMediaScrollView.swift
//  Nextcloud
//
//  Created by Milen on 13.10.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import Queuer

struct NCMediaScrollView: View {
//    static func == (lhs: NCMediaScrollView, rhs: NCMediaScrollView) -> Bool {
//        return lhs.metadatas == rhs.metadatas
//    }

    var metadatas: [tableMetadata]
    @Binding var isInSelectMode: Bool
    @Binding var selectedMetadatas: [tableMetadata]
    @Binding var columnCountStages: [Int]
    @Binding var columnCountStagesIndex: Int
    @Binding var shouldScrollToTop: Bool
    @Binding var title: String
    let proxy: ScrollViewProxy

//    var queuer: Queuer

    let onCellSelected: (ScaledThumbnail, Bool) -> Void
    let onCellContextMenuItemSelected: (ScaledThumbnail, ContextMenuSelection) -> Void

    @Namespace private var topID

    var body: some View {
        let _ = Self._printChanges()

        ScrollView {
            Spacer(minLength: 70).id(topID)

            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(metadatas.chunked(into: columnCountStages[columnCountStagesIndex]), id: \.self) { rowMetadatas in
                    NCMediaRow(metadatas: rowMetadatas, isInSelectMode: $isInSelectMode) { tappedThumbnail, isSelected in
                        onCellSelected(tappedThumbnail, isSelected)
                    } onCellContextMenuItemSelected: { thumbnail, selection in
                        onCellContextMenuItemSelected(thumbnail, selection)
                    }
                    .onAppear {
                        title = NCUtility().getTitleFromDate(rowMetadatas.first?.date as? Date ?? Date.now)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .onChange(of: shouldScrollToTop) { newValue in
            if newValue {
                withAnimation {
                    proxy.scrollTo(topID)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    shouldScrollToTop = false
                }
            }
        }
    }
}

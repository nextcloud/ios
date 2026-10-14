// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Persistent footer for presented adaptive video. Shares the viewer's thumbnail
/// model; selection is owned by the presenter so playback stops before changing pages.
struct NCMediaAdaptivePagingFooterView: View {
    @ObservedObject var model: NCMediaViewerModel
    let navigationHeight: CGFloat
    let onSelectPage: (_ index: Int) -> Void

    var body: some View {
        VStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
            pageNavigation
                .frame(height: navigationHeight)

            ZStack {
                if model.numberOfPages > 1 {
                    NCMediaViewerThumbnailStrip(model: model, onSelectPage: onSelectPage)
                }
            }
            .frame(height: NCMediaViewerThumbnail.preferredHeight)
            .ncAdaptiveThumbnailIsland()
        }
        .padding(NCMediaAdaptiveControlsLayout.spacing)
        .padding(.bottom, NCMediaAdaptiveControlsLayout.thumbnailBottomInset)
        .foregroundStyle(Color.ncViewerAdaptiveControlForeground)
        .tint(Color.ncViewerAdaptiveControlForeground)
        .fontWeight(.bold)
    }

    /// Also used by the video cover so the row stays in place when playback starts.
    var pageNavigation: some View {
        HStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
            pageButton(offset: -1, systemName: "chevron.left", title: "_previous_media_")
            pageButton(offset: 1, systemName: "chevron.right", title: "_next_media_")
        }
        .foregroundStyle(Color.ncViewerAdaptiveControlForeground)
        .fontWeight(.bold)
    }

    private func pageButton(offset: Int, systemName: String, title: String) -> some View {
        let index = model.selectedIndex + offset
        // Transition guards belong to selection actions; avoid fading buttons during upper swipes.
        let isEnabled = index >= 0 && index < model.numberOfPages
        return Button { onSelectPage(index) } label: {
            Label(NSLocalizedString(title, comment: ""), systemImage: systemName)
                .font(.subheadline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ncAdaptiveControlSurface(shape: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

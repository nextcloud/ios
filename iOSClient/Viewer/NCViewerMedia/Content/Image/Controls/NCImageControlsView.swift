// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Normal thumbnail overlay. Navigation and the information sheet remain in the hosting controller.
struct NCImageControlsView: View {
    @ObservedObject var model: NCMediaViewerModel

    var body: some View {
        if !model.isChromeHidden, model.numberOfPages > 1 {
            NCMediaViewerThumbnailStrip(model: model)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
                .zIndex(10)
        }
    }
}

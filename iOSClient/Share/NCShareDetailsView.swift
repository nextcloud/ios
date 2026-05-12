// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

struct NCShareDetailsView: View {
    var body: some View {
        Text("Details")
            .font(.body)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
    }
}

final class NCShareDetailsViewController: UIHostingController<NCShareDetailsView>, NCSharePagingContent {
    var textField: UIView? { nil }
    var height: CGFloat = 50

    init() {
        super.init(rootView: NCShareDetailsView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: NCShareDetailsView())
    }
}

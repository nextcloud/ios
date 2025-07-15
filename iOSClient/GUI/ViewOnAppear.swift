// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI

/// A protocol defining methods to handle view appearance events.
protocol ViewOnAppearHandling: ObservableObject {
    // Triggered when the view appears.
    func onViewAppear()
}

extension View {
    @discardableResult func defaultViewModifier(_ model: some ViewOnAppearHandling) -> some View {
        return modifier(DefaultViewModifier(viewModel: model))
    }
}

/// A view modifier that automatically calls a view model's `onViewAppear` function when the view appears on screen.
struct DefaultViewModifier<ViewModel: ViewOnAppearHandling>: ViewModifier {
    @ObservedObject var viewModel: ViewModel

    func body(content: Content) -> some View {
        content
        .onAppear {
            viewModel.onViewAppear()        // Call onViewAppear on view appearance
        }
    }
}

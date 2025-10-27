// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Wraps a SwiftUI view in a transparent `UIView` for use as a custom left or right view
/// in JDStatusBarNotification. Useful to display animated SwiftUI symbols.
@MainActor
func makeHostingNotificationPresenterView<Content: View>(_ content: Content, size: CGSize) -> UIView {
    let host = UIHostingController(rootView: content)
    host.view.backgroundColor = .clear
    host.view.isUserInteractionEnabled = false
    host.view.frame = .init(origin: .zero, size: size)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    return host.view
}

/// Animated gear symbol for JDStatusBarNotification.
struct NotificationPresenterGearSymbol: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                .symbolEffect(.rotate, options: .repeat(.continuous))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        } else {
            Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        }
    }
}

/// Animated gear symbol for JDStatusBarNotification.
struct NotificationPresenterTryArrowSymbol: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: "tray.and.arrow.down")
                .symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        } else {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        }
    }
}

/// Animated gear symbol for JDStatusBarNotification.
struct NotificationPresenterArrowShapeSymbol: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: "arrowshape.up.circle")
                .symbolEffect(.breathe, options: .repeat(.continuous))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        } else {
            Image(systemName: "arrowshape.up.circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .padding(4)
        }
    }
}

// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

public extension UIView {
    private static let blurEffectViewTag = -100

    /// Adds a background blur to the receiver and returns the created UIVisualEffectView.
    /// The blur view is inserted behind all other subviews and pinned to the view's edges.
    ///
    /// - Parameters:
    ///   - style: The `UIBlurEffect.Style` to use. Defaults to `.systemMaterial`.
    ///   - cornerRadius: Optional corner radius to apply to the blur view. If `nil`, no corner radius is applied.
    ///   - insets: Edge insets to apply when pinning the blur view. Defaults to `.zero`.
    /// - Returns: The configured and inserted `UIVisualEffectView`.
    ///
    /// Usage:
    /// ```swift
    /// // Simple background blur
    /// let blur = myView.addBlurBackground(style: .systemThinMaterialLight)
    ///
    /// // With corner radius and insets
    /// myView.addBlurBackground(style: .systemMaterial, cornerRadius: 12, insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
    /// ```
    @discardableResult
    func addBlurBackground(style: UIBlurEffect.Style = .systemMaterial,
                           cornerRadius: CGFloat? = nil,
                           insets: UIEdgeInsets = .zero) -> UIVisualEffectView {
        // Remove an existing blur (if any) that was previously added via this extension
        if let existingBlur = viewWithTag(Self.blurEffectViewTag) {
            existingBlur.removeFromSuperview()
        }

        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.isUserInteractionEnabled = false

        // Layout
        blurView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(blurView, at: 0)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            blurView.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom)
        ])

        if let radius = cornerRadius, radius > 0 {
            blurView.layer.cornerRadius = radius
            blurView.clipsToBounds = true
        }

        blurView.tag = Self.blurEffectViewTag
        return blurView
    }
}

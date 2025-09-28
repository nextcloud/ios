//
//  UIView+BlurVibrancy.swift
//
//  Created by Xcode Assistant.
//

import UIKit
import ObjectiveC

public extension UIView {
    // MARK: - Associated Keys
    private struct AssociatedKeys {
        static var blurEffectView = "com.nextcloud.ui.blurEffectView"
        static var vibrancyEffectView = "com.nextcloud.ui.vibrancyEffectView"
    }

    private var blurEffectView: UIVisualEffectView? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.blurEffectView) as? UIVisualEffectView }
        set { objc_setAssociatedObject(self, &AssociatedKeys.blurEffectView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var vibrancyEffectView: UIVisualEffectView? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.vibrancyEffectView) as? UIVisualEffectView }
        set { objc_setAssociatedObject(self, &AssociatedKeys.vibrancyEffectView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Adds a background blur to the receiver and returns the created UIVisualEffectView.
    /// The blur view is inserted behind all other subviews and pinned to the view's edges.
    ///
    /// - Parameters:
    ///   - style: The `UIBlurEffect.Style` to use. Defaults to `.systemMaterial`.
    ///   - cornerRadius: Optional corner radius to apply to the blur view. If `nil`, no corner radius is applied.
    ///   - insets: Edge insets to apply when pinning the blur view. Defaults to `.zero`.
    ///   - respectSafeArea: If `true`, the blur view is constrained to the safe area. Defaults to `false`.
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
                           insets: UIEdgeInsets = .zero,
                           respectSafeArea: Bool = false) -> UIVisualEffectView {
        // Remove an existing blur (if any) that was previously added via this extension
        if let existingBlur = blurEffectView {
            existingBlur.removeFromSuperview()
            blurEffectView = nil
        }

        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.isUserInteractionEnabled = false

        // Layout
        blurView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(blurView, at: 0)

        if respectSafeArea {
            NSLayoutConstraint.activate([
                blurView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: insets.left),
                blurView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -insets.right),
                blurView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: insets.top),
                blurView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -insets.bottom)
            ])
        } else {
            NSLayoutConstraint.activate([
                blurView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
                blurView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
                blurView.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
                blurView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom)
            ])
        }

        if let radius = cornerRadius, radius > 0 {
            blurView.layer.cornerRadius = radius
            blurView.clipsToBounds = true
        }

        blurEffectView = blurView
        return blurView
    }

    /// Adds a vibrancy overlay tied to a blur view and returns the vibrancy effect view.
    /// If `blurView` is `nil`, this method will use the previously added blur view or create a new one with default style.
    /// The vibrancy view is added inside the blur view's contentView and pinned to its edges.
    ///
    /// - Parameters:
    ///   - using: The blur view to attach vibrancy to. If `nil`, uses/creates one.
    ///   - style: The `UIVibrancyEffectStyle` to use. Defaults to `.label`.
    ///   - insets: Edge insets to apply when pinning the vibrancy view. Defaults to `.zero`.
    /// - Returns: The configured and inserted `UIVisualEffectView` for vibrancy, or `nil` if a blur effect could not be determined.
    @discardableResult
    func addVibrancyOverlay(using blurView: UIVisualEffectView? = nil,
                            style: UIVibrancyEffectStyle = .label,
                            insets: UIEdgeInsets = .zero) -> UIVisualEffectView? {
        // Ensure we have a blur view
        let blur: UIVisualEffectView
        if let provided = blurView {
            blur = provided
        } else if let existing = blurEffectView {
            blur = existing
        } else {
            // Create a default blur if none exists
            blur = addBlurBackground()
        }

        guard let blurEffect = blur.effect as? UIBlurEffect else { return nil }

        // Remove existing vibrancy (if any) that was previously added via this extension
        if let existingVibrancy = vibrancyEffectView {
            existingVibrancy.removeFromSuperview()
            vibrancyEffectView = nil
        }

        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: style)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.isUserInteractionEnabled = false
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false

        blur.contentView.addSubview(vibrancyView)
        NSLayoutConstraint.activate([
            vibrancyView.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: insets.left),
            vibrancyView.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -insets.right),
            vibrancyView.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: insets.top),
            vibrancyView.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -insets.bottom)
        ])

        vibrancyEffectView = vibrancyView
        return vibrancyView
    }

    /// Removes the blur and vibrancy effect views previously added via this extension.
    func removeBlurAndVibrancy() {
        if let vibrancy = vibrancyEffectView {
            vibrancy.removeFromSuperview()
            vibrancyEffectView = nil
        }
        if let blur = blurEffectView {
            blur.removeFromSuperview()
            blurEffectView = nil
        }
    }
}

// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

final class NCMediaViewerFloatingTitleView: UIView {
    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private let stackView = UIStackView()
    private let blurView = UIVisualEffectView(effect: nil)
    private weak var navigationBar: UINavigationBar?
    private var navigationBarConstraints: [NSLayoutConstraint] = []
    private var centerXConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        layoutMargins = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        clipsToBounds = false
        isAccessibilityElement = true

        configureLabels()
        configureBlurView()
        configureStackView()
        updateAppearance()

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: NCMediaViewerFloatingTitleView, _: UITraitCollection) in
            self?.updateAppearance()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Attach directly to the navigation bar to match real button layout.
    func attach(
        to navigationBar: UINavigationBar,
        widthMultiplier: CGFloat = 0.36,
        verticalOffset: CGFloat = 0
    ) {
        if self.navigationBar !== navigationBar || superview !== navigationBar {
            navigationBarConstraints.forEach { $0.isActive = false }
            navigationBarConstraints.removeAll()
            removeFromSuperview()
            navigationBar.addSubview(self)

            let centerXConstraint = centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor)
            let heightConstraint = heightAnchor.constraint(equalToConstant: navigationItemHeight(in: navigationBar))
            self.centerXConstraint = centerXConstraint
            self.heightConstraint = heightConstraint

            navigationBarConstraints = [
                centerXConstraint,
                topAnchor.constraint(equalTo: navigationBar.topAnchor, constant: verticalOffset),
                heightConstraint,
                widthAnchor.constraint(lessThanOrEqualTo: navigationBar.widthAnchor, multiplier: widthMultiplier)
            ]
            NSLayoutConstraint.activate(navigationBarConstraints)
            self.navigationBar = navigationBar
        }

        navigationBar.bringSubviewToFront(self)
        updateNavigationItemHeight()
        updateHorizontalAlignment()
    }

    func updateHorizontalAlignment() {
        centerXConstraint?.constant = 0
    }

    func updateNavigationItemHeight() {
        guard let navigationBar else {
            return
        }

        let height = navigationItemHeight(in: navigationBar)
        heightConstraint?.constant = height
        blurView.layer.cornerRadius = height / 2
    }

    // Use visible bar item height when possible.
    private func navigationItemHeight(in navigationBar: UINavigationBar) -> CGFloat {
        let heights = navigationBar.subviews.flatMap { subview in
            navigationItemHeights(
                from: subview,
                in: navigationBar
            )
        }

        return heights.max() ?? navigationBar.bounds.height
    }

    private func navigationItemHeights(
        from view: UIView,
        in navigationBar: UINavigationBar
    ) -> [CGFloat] {
        guard view !== self,
              !view.isDescendant(of: self),
              !view.isHidden,
              view.alpha > 0.01,
              view.bounds.width > 0,
              view.bounds.height > 0 else {
            return []
        }

        let frame = view.convert(view.bounds, to: navigationBar)
        let isVisibleNavigationFrame = frame.minY >= -1 &&
            frame.maxY <= navigationBar.bounds.height + 1 &&
            frame.height > 20 &&
            frame.width > 20 &&
            frame.width < navigationBar.bounds.width * 0.6

        let childHeights = view.subviews.flatMap { subview in
            navigationItemHeights(
                from: subview,
                in: navigationBar
            )
        }

        if isVisibleNavigationFrame {
            return childHeights + [frame.height]
        }

        return childHeights
    }

    func update(
        primaryText: String?,
        secondaryText: String?
    ) {
        let normalizedPrimaryText = primaryText?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedSecondaryText = secondaryText?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        primaryLabel.text = normalizedPrimaryText
        secondaryLabel.text = normalizedSecondaryText
        secondaryLabel.isHidden = normalizedSecondaryText?.isEmpty ?? true
        isHidden = normalizedPrimaryText?.isEmpty ?? true

        updateAppearance()

        accessibilityLabel = [
            normalizedPrimaryText,
            normalizedSecondaryText
        ]
        .compactMap { text in
            guard let text, !text.isEmpty else {
                return nil
            }

            return text
        }
        .joined(separator: ", ")
    }

    func clear() {
        update(
            primaryText: nil,
            secondaryText: nil
        )
    }

    private func configureLabels() {
        primaryLabel.font = .preferredFont(forTextStyle: .footnote)
        primaryLabel.textColor = .white
        primaryLabel.textAlignment = .center
        primaryLabel.adjustsFontForContentSizeCategory = true
        primaryLabel.lineBreakMode = .byTruncatingMiddle
        primaryLabel.numberOfLines = 1

        secondaryLabel.font = .preferredFont(forTextStyle: .caption2)
        secondaryLabel.textColor = .white.withAlphaComponent(0.82)
        secondaryLabel.textAlignment = .center
        secondaryLabel.adjustsFontForContentSizeCategory = true
        secondaryLabel.lineBreakMode = .byTruncatingTail
        secondaryLabel.numberOfLines = 1
    }

    private func configureBlurView() {
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        blurView.clipsToBounds = true
        blurView.layer.cornerCurve = .continuous
        addSubview(blurView)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configureStackView() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 2

        stackView.addArrangedSubview(primaryLabel)
        stackView.addArrangedSubview(secondaryLabel)
        addSubview(stackView)
        bringSubviewToFront(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor)
        ])
    }

    private func updateAppearance() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark

        blurView.effect = UIBlurEffect(
            style: isDarkMode
                ? .systemChromeMaterialDark
                : .systemChromeMaterialLight
        )

        let textColor: UIColor = isDarkMode ? .white : .black

        primaryLabel.textColor = textColor
        secondaryLabel.textColor = textColor.withAlphaComponent(0.82)
    }
}


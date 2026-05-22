// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

final class NCViewerFloatingTitleView: UIView {
    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private let stackView = UIStackView()
    private weak var navigationBar: UINavigationBar?
    private var navigationBarConstraints: [NSLayoutConstraint] = []
    private var centerXConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        isAccessibilityElement = true

        configureLabels()
        configureStackView()
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

        heightConstraint?.constant = navigationItemHeight(in: navigationBar)
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
        secondaryText: String?,
        textColor: UIColor
    ) {
        let normalizedPrimaryText = primaryText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSecondaryText = secondaryText?.trimmingCharacters(in: .whitespacesAndNewlines)

        primaryLabel.text = normalizedPrimaryText
        primaryLabel.textColor = textColor
        secondaryLabel.text = normalizedSecondaryText
        secondaryLabel.textColor = textColor.withAlphaComponent(0.82)
        secondaryLabel.isHidden = normalizedSecondaryText?.isEmpty ?? true
        isHidden = normalizedPrimaryText?.isEmpty ?? true

        accessibilityLabel = [normalizedPrimaryText, normalizedSecondaryText]
            .compactMap { text in
                guard let text, !text.isEmpty else { return nil }
                return text
            }
            .joined(separator: ", ")
    }

    func clear() {
        update(
            primaryText: nil,
            secondaryText: nil,
            textColor: .white
        )
    }

    private func configureLabels() {
        primaryLabel.font = .preferredFont(forTextStyle: .subheadline)
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

    private func configureStackView() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 2

        stackView.addArrangedSubview(primaryLabel)
        stackView.addArrangedSubview(secondaryLabel)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor)
        ])
    }
}

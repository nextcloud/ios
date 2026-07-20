// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

final class NCMediaViewerFloatingTitleView: UIView {
    private weak var navigationBar: UINavigationBar?
    private var navigationBarConstraints: [NSLayoutConstraint] = []
    private var centerXConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    private let titleButton: UIButton = {
        let button: UIButton

        if #available(iOS 26.0, *) {
            var configuration = UIButton.Configuration.glass()
            button = UIButton(configuration: configuration)
        } else {
            var configuration = UIButton.Configuration.plain()
            button = UIButton(configuration: configuration)
        }

        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = false
        button.adjustsImageSizeForAccessibilityContentSizeCategory = false

        return button
    }()

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        clipsToBounds = false
        isAccessibilityElement = true

        addSubview(titleButton)

        NSLayoutConstraint.activate([
            titleButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleButton.topAnchor.constraint(equalTo: topAnchor),
            titleButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var configuration = titleButton.configuration
        configuration?.titleAlignment = .center
        configuration?.titleLineBreakMode = .byTruncatingMiddle

        titleButton.configuration = configuration
        titleButton.titleLabel?.numberOfLines = 1
    }

    func attach(to navigationBar: UINavigationBar, widthMultiplier: CGFloat = 0.36, verticalOffset: CGFloat = 0) {
        if self.navigationBar !== navigationBar || superview !== navigationBar {
            navigationBarConstraints.forEach { $0.isActive = false }
            navigationBarConstraints.removeAll()
            removeFromSuperview()
            navigationBar.addSubview(self)

            let centerXConstraint = centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor)
            let heightConstraint = heightAnchor.constraint(equalToConstant: navigationItemHeight(in: navigationBar))
            let topConstraint = topAnchor.constraint(equalTo: navigationBar.topAnchor, constant: verticalOffset)
            self.centerXConstraint = centerXConstraint
            self.heightConstraint = heightConstraint

            navigationBarConstraints = [
                centerXConstraint,
                topConstraint,
                heightConstraint,
                widthAnchor.constraint(
                    lessThanOrEqualTo: navigationBar.widthAnchor,
                    multiplier: widthMultiplier
                )
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
    }

    private func navigationItemHeight(in navigationBar: UINavigationBar) -> CGFloat {
        min(44, navigationBar.bounds.height)
    }

    func clear() {
        update(
            primaryText: nil,
            secondaryText: nil
        )
    }

    func update(primaryText: String?, secondaryText: String?) {
        var configuration = titleButton.configuration

        configuration?.attributedTitle = AttributedString(
            primaryText ?? "",
            attributes: AttributeContainer([
                .font: UIFont.systemFont(
                    ofSize: 13,
                    weight: .semibold
                )
            ])
        )

        if let secondaryText,
           !secondaryText.isEmpty {
            configuration?.attributedSubtitle = AttributedString(
                secondaryText,
                attributes: AttributeContainer([
                    .font: UIFont.systemFont(
                        ofSize: 11,
                        weight: .regular
                    )
                ])
            )
        } else {
            configuration?.attributedSubtitle = nil
        }
        titleButton.configuration = configuration

        isHidden = primaryText?.isEmpty ?? true

        accessibilityLabel = [
            primaryText,
            secondaryText
        ]
        .compactMap { text in
            guard let text, !text.isEmpty else {
                return nil
            }

            return text
        }
        .joined(separator: ", ")
    }
}

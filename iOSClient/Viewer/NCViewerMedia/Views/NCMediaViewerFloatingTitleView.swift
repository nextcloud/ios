// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

final class NCMediaViewerFloatingTitleView: UIView {
    private var lastLayoutWidth: CGFloat = 0
    private let maximumWidth: CGFloat = 400
    private let preferredHeight: CGFloat = 44

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
        button.isEnabled = true
        button.tintAdjustmentMode = .normal
        button.adjustsImageSizeForAccessibilityContentSizeCategory = false

        return button
    }()

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = true
        backgroundColor = .clear
        clipsToBounds = true
        isAccessibilityElement = true

        titleButton.clipsToBounds = true
        titleButton.titleLabel?.numberOfLines = 1
        titleButton.titleLabel?.lineBreakMode = .byTruncatingMiddle
        titleButton.titleLabel?.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        titleButton.titleLabel?.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        addSubview(titleButton)

        NSLayoutConstraint.activate([
            titleButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleButton.topAnchor.constraint(equalTo: topAnchor),
            titleButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: maximumWidth,
            height: preferredHeight
        )
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds.width != lastLayoutWidth else {
            return
        }

        lastLayoutWidth = bounds.width

        let leadingInset = titleButton.configuration?.contentInsets.leading ?? 0
        let trailingInset = titleButton.configuration?.contentInsets.trailing ?? 0
        let availableWidth = max(
            0,
            bounds.width - leadingInset - trailingInset
        )

        titleButton.titleLabel?.preferredMaxLayoutWidth = availableWidth
        titleButton.titleLabel?.numberOfLines = 1
        titleButton.titleLabel?.lineBreakMode = .byTruncatingMiddle
        titleButton.titleLabel?.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        titleButton.subtitleLabel?.preferredMaxLayoutWidth = availableWidth
        titleButton.subtitleLabel?.numberOfLines = 1
        titleButton.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
        titleButton.subtitleLabel?.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        var configuration = titleButton.configuration
        configuration?.titleAlignment = .center
        configuration?.titleLineBreakMode = .byTruncatingMiddle
        configuration?.subtitleLineBreakMode = .byTruncatingMiddle
        titleButton.configuration = configuration
    }

    func clear() {
        update(
            primaryText: nil,
            secondaryText: nil
        )
    }

    func update(
        primaryText: String?,
        secondaryText: String?
    ) {
        var configuration = titleButton.configuration
        configuration?.title = primaryText ?? ""
        configuration?.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(
                    ofSize: 13,
                    weight: .semibold
                )
                return outgoing
            }

        if let secondaryText,
           !secondaryText.isEmpty {
            configuration?.subtitle = secondaryText
            configuration?.subtitleTextAttributesTransformer =
                UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = UIFont.systemFont(
                        ofSize: 11,
                        weight: .regular
                    )
                    return outgoing
                }
        } else {
            configuration?.subtitle = nil
        }
        titleButton.configuration = configuration
        invalidateIntrinsicContentSize()

        lastLayoutWidth = 0
        setNeedsLayout()

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

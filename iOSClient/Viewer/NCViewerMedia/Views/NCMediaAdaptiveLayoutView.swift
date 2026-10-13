// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// Single experimental switch for images, audio and both video engines. See ../README.md.
enum NCMediaAdaptiveLayoutConfiguration {
    /// Enabled for experimental verification; set to false to use the normal layout.
    static let isAdaptiveLayoutEnabled = true
}

/// Arranges the same media surface above the fold and independent controls below it.
/// Without an active horizontal division, the normal controls remain visible.
final class NCMediaAdaptiveLayoutView: UIView {
    private let mediaView: UIView
    private let normalControlsView: UIView
    private let makeAdaptiveControlsView: () -> UIView?
    private var adaptiveControlsView: UIView?
    private var normalLayoutConstraints: [NSLayoutConstraint] = []

    /// Container eligibility, inherited from the central switch and selected media type.
    /// Image/video-cover paging disables it for unsupported media types without changing the feature switch.
    var isLayoutEnabled: Bool {
        didSet {
            guard isLayoutEnabled != oldValue else {
                return
            }
            if isLayoutEnabled {
                NSLayoutConstraint.deactivate(normalLayoutConstraints)
            }
            mediaView.translatesAutoresizingMaskIntoConstraints = isLayoutEnabled
            normalControlsView.translatesAutoresizingMaskIntoConstraints = isLayoutEnabled
            if !isLayoutEnabled {
                NSLayoutConstraint.activate(normalLayoutConstraints)
            }
            setNeedsLayout()
        }
    }

    /// Whether this container currently has a suitable active horizontal division.
    private(set) var isFoldedLayout = false
    /// Called after changing control visibility; owners update navigation and auto-hide behavior.
    var onLayoutModeChanged: ((Bool) -> Void)?

    init(
        mediaView: UIView,
        normalControlsView: UIView,
        isLayoutEnabled: Bool = NCMediaAdaptiveLayoutConfiguration.isAdaptiveLayoutEnabled,
        adaptiveControlsView: @escaping () -> UIView?
    ) {
        self.mediaView = mediaView
        self.normalControlsView = normalControlsView
        self.makeAdaptiveControlsView = adaptiveControlsView
        self.isLayoutEnabled = isLayoutEnabled

        super.init(frame: .zero)

        mediaView.translatesAutoresizingMaskIntoConstraints = isLayoutEnabled
        normalControlsView.translatesAutoresizingMaskIntoConstraints = isLayoutEnabled
        addSubview(mediaView)
        addSubview(normalControlsView)

        normalLayoutConstraints = [
            mediaView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mediaView.topAnchor.constraint(equalTo: topAnchor),
            mediaView.bottomAnchor.constraint(equalTo: bottomAnchor),

            normalControlsView.leadingAnchor.constraint(equalTo: leadingAnchor),
            normalControlsView.trailingAnchor.constraint(equalTo: trailingAnchor),
            normalControlsView.topAnchor.constraint(equalTo: topAnchor),
            normalControlsView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        if !isLayoutEnabled {
            NSLayoutConstraint.activate(normalLayoutConstraints)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var divisionFrames: [CGRect] = []
        if #available(iOS 27.1, *), isLayoutEnabled {
            // Reading here lets UIKit track changes even when the bounds stay the same.
            divisionFrames = reservedRegions(kind: .division)
                .filter(\.isActive)
                .map(\.frame)
        }

        updateLayout(divisionFrames: divisionFrames)
    }

    func updateLayout(divisionFrames: [CGRect]) {
        let activeDivisionFrames = isLayoutEnabled ? divisionFrames : []
        let division = activeDivisionFrames
            .map { bounds.intersection($0) }
            .first { frame in
                !frame.isNull &&
                    frame.width >= bounds.width - 1 &&
                    frame.width > frame.height &&
                    frame.height > 0 &&
                    frame.minY > bounds.minY &&
                    frame.maxY < bounds.maxY
            }

        if isLayoutEnabled {
            if division != nil, adaptiveControlsView == nil, let controlsView = makeAdaptiveControlsView() {
                controlsView.translatesAutoresizingMaskIntoConstraints = true
                controlsView.isHidden = true
                controlsView.clipsToBounds = true
                addSubview(controlsView)
                adaptiveControlsView = controlsView
            }
            normalControlsView.frame = bounds
        }

        // Keep the normal layout usable if the adaptive controls cannot be supplied.
        let foldedDivision = adaptiveControlsView != nil ? division : nil
        if let division = foldedDivision {
            mediaView.frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: division.minY - bounds.minY)
            adaptiveControlsView?.frame = CGRect(x: bounds.minX, y: division.maxY, width: bounds.width, height: bounds.maxY - division.maxY)
        } else if isLayoutEnabled {
            mediaView.frame = bounds
            adaptiveControlsView?.frame = bounds
        }

        let isFolded = foldedDivision != nil
        guard isFoldedLayout != isFolded else {
            return
        }

        normalControlsView.isHidden = isFolded
        adaptiveControlsView?.isHidden = !isFolded
        isFoldedLayout = isFolded
        onLayoutModeChanged?(isFolded)
    }
}

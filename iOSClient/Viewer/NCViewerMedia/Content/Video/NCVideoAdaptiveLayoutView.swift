// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

// Keeps the video surface and both controls views alive when the device folds or unfolds.
final class NCVideoAdaptiveLayoutView: UIView {
    private let videoView: UIView
    private let normalControlsView: UIView
    private let makeAdaptiveControlsView: () -> UIView?
    private var adaptiveControlsView: UIView?
    private var normalLayoutConstraints: [NSLayoutConstraint] = []

    // Experimental layout, enabled only from code while it is being developed.
    var isAdaptiveLayoutEnabled = false {
        didSet {
            guard isAdaptiveLayoutEnabled != oldValue else {
                return
            }
            if isAdaptiveLayoutEnabled {
                NSLayoutConstraint.deactivate(normalLayoutConstraints)
            }
            videoView.translatesAutoresizingMaskIntoConstraints = isAdaptiveLayoutEnabled
            normalControlsView.translatesAutoresizingMaskIntoConstraints = isAdaptiveLayoutEnabled
            if !isAdaptiveLayoutEnabled {
                NSLayoutConstraint.activate(normalLayoutConstraints)
            }
            setNeedsLayout()
        }
    }

    private(set) var isFoldedLayout = false
    var onLayoutModeChanged: ((Bool) -> Void)?

    init(videoView: UIView, normalControlsView: UIView, adaptiveControlsView: @escaping () -> UIView?) {
        self.videoView = videoView
        self.normalControlsView = normalControlsView
        self.makeAdaptiveControlsView = adaptiveControlsView

        super.init(frame: .zero)

        videoView.translatesAutoresizingMaskIntoConstraints = false
        normalControlsView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoView)
        addSubview(normalControlsView)

        normalLayoutConstraints = [
            videoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: trailingAnchor),
            videoView.topAnchor.constraint(equalTo: topAnchor),
            videoView.bottomAnchor.constraint(equalTo: bottomAnchor),

            normalControlsView.leadingAnchor.constraint(equalTo: leadingAnchor),
            normalControlsView.trailingAnchor.constraint(equalTo: trailingAnchor),
            normalControlsView.topAnchor.constraint(equalTo: topAnchor),
            normalControlsView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        NSLayoutConstraint.activate(normalLayoutConstraints)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var divisionFrames: [CGRect] = []
        if #available(iOS 27.1, *), isAdaptiveLayoutEnabled {
            // Reading here lets UIKit track changes even when the bounds stay the same.
            divisionFrames = reservedRegions(kind: .division)
                .filter(\.isActive)
                .map(\.frame)
        }

        updateLayout(divisionFrames: divisionFrames)
    }

    func updateLayout(divisionFrames: [CGRect]) {
        let activeDivisionFrames = isAdaptiveLayoutEnabled ? divisionFrames : []
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

        if isAdaptiveLayoutEnabled {
            if adaptiveControlsView == nil, let controlsView = makeAdaptiveControlsView() {
                controlsView.translatesAutoresizingMaskIntoConstraints = true
                controlsView.isHidden = true
                addSubview(controlsView)
                adaptiveControlsView = controlsView
            }
            normalControlsView.frame = bounds
        }

        if let division {
            videoView.frame = CGRect(
                x: bounds.minX,
                y: bounds.minY,
                width: bounds.width,
                height: division.minY - bounds.minY
            )
            adaptiveControlsView?.frame = CGRect(
                x: bounds.minX,
                y: division.maxY,
                width: bounds.width,
                height: bounds.maxY - division.maxY
            )
        } else if isAdaptiveLayoutEnabled {
            videoView.frame = bounds
            adaptiveControlsView?.frame = bounds
        }

        let isFolded = division != nil
        guard isFoldedLayout != isFolded else {
            return
        }

        normalControlsView.isHidden = isFolded
        adaptiveControlsView?.isHidden = !isFolded
        isFoldedLayout = isFolded
        onLayoutModeChanged?(isFolded)
    }
}

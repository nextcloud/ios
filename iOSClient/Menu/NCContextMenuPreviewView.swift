// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// Context menu preview that covers the pressed cell with a copy of it, then reveals its whole name once the menu opens.
/// It is sized for the whole name from the start, since UIKit fixes a targeted preview's size when the press begins.
class NCContextMenuPreviewView: UIView {
    enum RowAlignment {
        /// The name grows downward, keeping a grid tile's image in place.
        case top
        /// The name grows above and below the row, keeping a list row's icon and buttons in place.
        case center
    }

    private static let fallbackCornerRadius: CGFloat = 10

    private let rowCell: UIView
    private let fullNameCell: UIView
    private weak var sourceCell: UIView?

    /// Where the pressed cell sits within the preview.
    var rowFrame: CGRect {
        rowCell.frame
    }

    /// The shadow of the row alone, so nothing shows around it until the name expands.
    var rowShadowPath: UIBezierPath {
        UIBezierPath(roundedRect: rowCell.frame, cornerRadius: Self.fallbackCornerRadius)
    }

    init(sourceCell: UIView, rowCell: UIView, fullNameCell: UIView, rowAlignment: RowAlignment) {
        self.sourceCell = sourceCell
        self.rowCell = rowCell
        self.fullNameCell = fullNameCell

        super.init(frame: fullNameCell.bounds)

        if rowAlignment == .center {
            rowCell.frame.origin.y = (bounds.height - rowCell.bounds.height) / 2
        }

        fullNameCell.alpha = 0
        rowCell.layer.masksToBounds = true
        addSubview(fullNameCell)
        addSubview(rowCell)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        roundRowCorners()
    }

    /// Crossfades to the whole name, hiding the pressed cell since UIKit may move the preview away from it; reversed on dismissal.
    func setFullNameVisible(_ visible: Bool, alongside animator: UIContextMenuInteractionAnimating?) {
        let update = {
            self.rowCell.alpha = visible ? 0 : 1
            self.fullNameCell.alpha = visible ? 1 : 0
        }

        if visible {
            roundRowCorners()
            sourceCell?.isHidden = true
        }

        guard let animator else {
            update()
            sourceCell?.isHidden = visible
            return
        }

        animator.addAnimations(update)
        animator.addCompletion { [weak self] in
            self?.sourceCell?.isHidden = visible
        }
    }

    /// UIKit rounds only the platter's outer corners; the row copy sits inside it, so round its corners alike.
    private func roundRowCorners() {
        var platterLayer: CALayer?
        var ancestor = superview

        while let view = ancestor, platterLayer == nil {
            if view.layer.cornerRadius > 0 {
                platterLayer = view.layer
            }

            ancestor = view.superview
        }

        rowCell.layer.cornerRadius = platterLayer?.cornerRadius ?? Self.fallbackCornerRadius
        rowCell.layer.cornerCurve = platterLayer?.cornerCurve ?? .continuous
    }
}

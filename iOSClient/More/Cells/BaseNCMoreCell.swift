//
//  BaseNCMoreCell.swift
//  Nextcloud
//
//  Created by Milen on 15.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation

class BaseNCMoreCell: UITableViewCell {
    let selectionColor: UIView = UIView()
    let defaultCornerRadius: CGFloat = 10.0

    override var frame: CGRect {
        get {
            return super.frame
        }
        set (newFrame) {
            var frame = newFrame
            let newWidth = frame.width * 0.90
            let space = (frame.width - newWidth) / 2
            frame.size.width = newWidth
            frame.origin.x += space
            super.frame = frame
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        selectedBackgroundView = selectionColor
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = defaultCornerRadius
    }
}

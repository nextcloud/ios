//
//  NCMoreUserCell.swift
//  Nextcloud
//
//  Created by Milen on 14.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import MarqueeLabel

class NCMoreUserCell: UITableViewCell {

    @IBOutlet weak var displayName: UILabel!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var status: MarqueeLabel!

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
}

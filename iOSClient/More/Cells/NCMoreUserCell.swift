//
//  NCMoreUserCell.swift
//  Nextcloud
//
//  Created by Milen on 14.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import MarqueeLabel

class NCMoreUserCell: BaseNCMoreCell {
    @IBOutlet weak var displayName: UILabel!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var status: MarqueeLabel!

    static let reuseIdentifier = "NCMoreUserCell"

    static func fromNib() -> UINib {
        return UINib(nibName: "NCMoreUserCell", bundle: nil)
    }
}

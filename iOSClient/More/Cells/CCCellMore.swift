//
//  CCCellMore.swift
//  Nextcloud
//
//  Created by Milen on 14.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation

class CCCellMore: BaseNCMoreCell {
    @IBOutlet weak var labelText: UILabel!
    @IBOutlet weak var imageIcon: UIImageView!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var separatorHeigth: NSLayoutConstraint!

    static let reuseIdentifier = "CCCellMore"
}

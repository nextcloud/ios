//
//  NCSectionHeader.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

class NCSectionHeader: UICollectionReusableView {
    @IBOutlet weak var labelSection: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = UIColor.clear
        self.labelSection.text = ""
    }
}

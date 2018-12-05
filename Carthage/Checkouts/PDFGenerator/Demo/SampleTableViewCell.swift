//
//  SampleTableViewCell.swift
//  PDFGenerator
//
//  Created by Suguru Kishimoto on 2016/02/27.
//
//

import UIKit

class SampleTableViewCell: UITableViewCell {

    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}

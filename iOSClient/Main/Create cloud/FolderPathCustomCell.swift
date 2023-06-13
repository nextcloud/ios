//
//  FolderPathCustomCell.swift
//  Nextcloud
//
//  Created by Sumit on 28/04/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation

class FolderPathCustomCell: XLFormButtonCell{
    
    @IBOutlet weak var photoLabel: UILabel!
    @IBOutlet weak var folderImage: UIImageView!
    @IBOutlet weak var bottomLineView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func configure() {
        super.configure()
    }
    
    override func update() {
        super.update()
        if (rowDescriptor.tag == "PhotoButtonDestinationFolder"){
            bottomLineView.isHidden = true
        }else{
            bottomLineView.isHidden = false
        }
    }
}

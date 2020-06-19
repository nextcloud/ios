//
//  CCCellMain.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 05.06.20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import UIKit
import MGSwipeTableCell

class CCCellMain: MGSwipeTableCell, NCImageCellProtocol {

    @IBOutlet weak var file: UIImageView!
    @IBOutlet weak var status: UIImageView!
    @IBOutlet weak var favorite: UIImageView!
    @IBOutlet weak var local: UIImageView!
    @IBOutlet weak var comment: UIImageView!
    @IBOutlet weak var shared: UIImageView!
    @IBOutlet weak var viewShared: UIView!
    @IBOutlet weak var more: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfoFile: UILabel!

    @IBOutlet weak var labelTitleTrailingConstraint: NSLayoutConstraint!

    var filePreviewImageView : UIImageView {
        get{
         return file
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.initCell()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.initCell()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        self.contentView.preservesSuperviewLayoutMargins = false
    }
    
    func initCell() {
        separatorInset = UIEdgeInsets.init(top: 0, left: 60, bottom: 0, right: 0)
        accessoryType = UITableViewCell.AccessoryType.none
        file.image = nil
        file.layer.cornerRadius = 6
        file.layer.masksToBounds = true
        status.image = nil
        favorite.image = nil
        shared.image = nil
        local.image = nil
        comment.image = nil
        shared.isUserInteractionEnabled = false
        backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        // change color selection
        let selectionColor = UIView()
        selectionColor.backgroundColor = NCBrandColor.sharedInstance.select
        selectedBackgroundView = selectionColor
        tintColor = NCBrandColor.sharedInstance.brandElement
        
        labelTitle.textColor = NCBrandColor.sharedInstance.textView
        
        file.backgroundColor = nil
    }

}

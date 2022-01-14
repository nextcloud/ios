//
//  NCShareAdvancePermissionHeader.swift
//  Nextcloud
//
//  Created by T-systems on 10/08/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

class NCShareAdvancePermissionHeader: UIView {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fileName: UILabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var favorite: UIButton!
    @IBOutlet weak var fullWidthImageView: UIImageView!
    private let appDelegate = UIApplication.shared.delegate as? AppDelegate
    var delegate: NCShareAdvancePermissionHeaderDelegate?
    var ocId = ""
    
    @IBAction func touchUpInsideFavorite(_ sender: UIButton) {
        delegate?.favoriteClicked()
    }
}

protocol NCShareAdvancePermissionHeaderDelegate {
    func favoriteClicked()
//    func textFieldSelected(_ textField: UITextField)
//    func textFieldTextChanged(_ textField: UITextField)
}

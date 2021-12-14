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
    
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var delegate: NCShareAdvancePermissionHeaderDelegate?
    var ocId = ""
        
    @IBAction func touchUpInsideFavorite(_ sender: UIButton) {
        delegate?.favoriteClicked()
//        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
//            NCNetworking.shared.favoriteMetadata(metadata, urlBase: appDelegate.urlBase) { (errorCode, errorDescription) in
//                if errorCode == 0 {
//                    if !metadata.favorite {
//                        self.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite, size: 20), for: .normal)
//                    } else {
//                        self.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.textInfo, size: 20), for: .normal)
//                    }
//                } else {
//                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
//                }
//            }
//        }
    }
}

protocol NCShareAdvancePermissionHeaderDelegate {
    func favoriteClicked()
//    func textFieldSelected(_ textField: UITextField)
//    func textFieldTextChanged(_ textField: UITextField)
}

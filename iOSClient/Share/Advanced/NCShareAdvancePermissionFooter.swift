//
//  NCShareAdvancePermissionFooter.swift
//  Nextcloud
//
//  Created by T-systems on 10/08/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

protocol NCShareAdvanceFotterDelegate: AnyObject {
    func dismissShareAdvanceView(shouldSave: Bool)
}

class NCShareAdvancePermissionFooter: UIView {
    @IBOutlet weak var buttonCancel: UIButton!
    @IBOutlet weak var buttonNext: UIButton!
    weak var delegate: NCShareAdvanceFotterDelegate?
    
    func setupUI(with share: TableShareable, delegate: NCShareAdvanceFotterDelegate?) {
        self.delegate = delegate

        backgroundColor = .clear
        addShadow(location: .top)

        buttonCancel.addTarget(self, action: #selector(cancelClicked), for: .touchUpInside)
        buttonCancel.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        buttonCancel.layer.cornerRadius = 10
        buttonCancel.layer.masksToBounds = true
        buttonCancel.layer.borderWidth = 1

        if NCManageDatabase.shared.getTableShare(account: share.account, idShare: share.idShare) == nil {
            buttonNext.setTitle(NSLocalizedString("_next_", comment: ""), for: .normal)
        } else {
            buttonNext.setTitle(NSLocalizedString("_apply_changes_", comment: ""), for: .normal)
        }
        buttonNext.layer.cornerRadius = 10
        buttonNext.layer.masksToBounds = true
        buttonNext.backgroundColor = NCBrandColor.shared.brand
        buttonNext.addTarget(self, action: #selector(nextClicked), for: .touchUpInside)
    }

    @objc func cancelClicked() {
        delegate?.dismissShareAdvanceView(shouldSave: false)
    }

    @objc func nextClicked() {
        delegate?.dismissShareAdvanceView(shouldSave: true)
    }
}

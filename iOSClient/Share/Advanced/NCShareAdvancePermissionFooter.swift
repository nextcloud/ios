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

    func setupUI(delegate: NCShareAdvanceFotterDelegate?) {
        self.delegate = delegate

        backgroundColor = .clear
        addShadow(location: .top)

        buttonCancel.addTarget(self, action: #selector(cancelClicked), for: .touchUpInside)
        buttonCancel.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        buttonCancel.layer.cornerRadius = 10
        buttonCancel.layer.masksToBounds = true

        buttonNext.setTitle(NSLocalizedString("_save_", comment: ""), for: .normal)
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

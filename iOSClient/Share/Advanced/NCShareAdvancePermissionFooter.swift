//
//  NCShareAdvancePermissionFooter.swift
//  Nextcloud
//
//  Created by T-systems on 09/08/21.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

protocol NCShareAdvanceFotterDelegate: AnyObject {
    var isNewShare: Bool { get }
    func dismissShareAdvanceView(shouldSave: Bool)
}

class NCShareAdvancePermissionFooter: UIView {
    @IBOutlet weak var buttonCancel: UIButton!
    @IBOutlet weak var buttonNext: UIButton!
    weak var delegate: NCShareAdvanceFotterDelegate?

    func setupUI(delegate: NCShareAdvanceFotterDelegate?) {
        self.delegate = delegate
        backgroundColor = .clear

        buttonCancel.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        buttonCancel.layer.cornerRadius = 25
        buttonCancel.layer.masksToBounds = true
        buttonCancel.layer.borderWidth = 1
        buttonCancel.layer.borderColor = UIColor.systemGray.cgColor
        buttonCancel.backgroundColor = .secondarySystemBackground
        buttonCancel.addTarget(self, action: #selector(cancelClicked), for: .touchUpInside)
        buttonCancel.setTitleColor(.systemGray, for: .normal)

        buttonNext.setTitle(NSLocalizedString(delegate?.isNewShare == true ? "_share_" : "_save_", comment: ""), for: .normal)
        buttonNext.layer.cornerRadius = 25
        buttonNext.layer.masksToBounds = true
        buttonNext.backgroundColor = NCBrandColor.shared.brand
        buttonNext.addTarget(self, action: #selector(nextClicked), for: .touchUpInside)
        buttonNext.setTitleColor(NCBrandColor.shared.brandText, for: .normal)
    }

    @objc func cancelClicked() {
        delegate?.dismissShareAdvanceView(shouldSave: false)
    }

    @objc func nextClicked() {
        delegate?.dismissShareAdvanceView(shouldSave: true)
    }
}

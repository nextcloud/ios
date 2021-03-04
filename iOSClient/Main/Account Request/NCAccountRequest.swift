//
//  NCRenameFile.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

import Foundation
import NCCommunication

class NCAccountRequest: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var okButton: UIButton!

    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = NSLocalizedString("_account_request_", comment: "")
        
        okButton.setTitle(NSLocalizedString("_ok_", comment: ""), for: .normal)
        okButton.setTitleColor(NCBrandColor.shared.brandText, for: .normal)
        okButton.layer.cornerRadius = 15
        okButton.layer.masksToBounds = true
        okButton.layer.backgroundColor = NCBrandColor.shared.brand.cgColor
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - Action
    
    @IBAction func ok(_ sender: Any) {
        
        dismiss(animated: true)
    }
}

//
//  NCCreateFormUploadConflictCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/03/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

import UIKit

class NCCreateFormUploadConflictCell: UITableViewCell {

    @IBOutlet weak var labelFileName: UILabel!

    @IBOutlet weak var imageAlreadyExistingFile: UIImageView!
    @IBOutlet weak var imageNewFile: UIImageView!

    @IBOutlet weak var labelDetailAlreadyExistingFile: UILabel!
    @IBOutlet weak var labelDetailNewFile: UILabel!

    @IBOutlet weak var switchAlreadyExistingFile: UISwitch!
    @IBOutlet weak var switchNewFile: UISwitch!

    weak var delegate: NCCreateFormUploadConflictCellDelegate?
    var ocId: String = ""

    @IBAction func valueChangedSwitchNewFile(_ sender: Any) {
        delegate?.valueChangedSwitchNewFile(with: ocId, isOn: switchNewFile.isOn)
    }

    @IBAction func valueChangedSwitchAlreadyExistingFile(_ sender: Any) {
        delegate?.valueChangedSwitchAlreadyExistingFile(with: ocId, isOn: switchAlreadyExistingFile.isOn)
    }
}

protocol NCCreateFormUploadConflictCellDelegate: AnyObject {

    func valueChangedSwitchNewFile(with ocId: String, isOn: Bool)
    func valueChangedSwitchAlreadyExistingFile(with ocId: String, isOn: Bool)
}

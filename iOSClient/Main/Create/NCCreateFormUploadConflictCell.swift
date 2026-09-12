// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCCreateFormUploadConflictCell: UITableViewCell {

    @IBOutlet weak var labelFileName: UILabel!
    @IBOutlet weak var labelExtensionFileName: UILabel!

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

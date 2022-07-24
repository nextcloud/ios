//
//  NCColorPicker.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/07/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

class NCColorPicker: UIViewController {

    @IBOutlet weak var orangeButton: UIButton!
    @IBOutlet weak var redButton: UIButton!
    @IBOutlet weak var violaButton: UIButton!
    @IBOutlet weak var blueButton: UIButton!
    @IBOutlet weak var yellowButton: UIButton!
    @IBOutlet weak var greenButton: UIButton!
    @IBOutlet weak var grayButton: UIButton!
    @IBOutlet weak var defaultButton: UIButton!

    @IBOutlet weak var orangeText: UITextField!
    @IBOutlet weak var redText: UITextField!
    @IBOutlet weak var violaText: UITextField!
    @IBOutlet weak var blueText: UITextField!
    @IBOutlet weak var yellowText: UITextField!
    @IBOutlet weak var greenText: UITextField!
    @IBOutlet weak var grayText: UITextField!
    @IBOutlet weak var defaultLabel: UILabel!

    var metadata: tableMetadata?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        orangeButton.backgroundColor = .orange
        orangeButton.layer.cornerRadius = 5
        orangeButton.layer.masksToBounds = true
        orangeText.text = NSLocalizedString("_orange_", comment: "")

        redButton.backgroundColor = .red
        redButton.layer.cornerRadius = 5
        redButton.layer.masksToBounds = true
        redText.text = NSLocalizedString("_red_", comment: "")

        violaButton.backgroundColor = UIColor(hex: "#8f00ff")
        violaButton.layer.cornerRadius = 5
        violaButton.layer.masksToBounds = true
        violaText.text = NSLocalizedString("_viola_", comment: "")

        blueButton.backgroundColor = .blue
        blueButton.layer.cornerRadius = 5
        blueButton.layer.masksToBounds = true
        blueText.text = NSLocalizedString("_blue_", comment: "")

        yellowButton.backgroundColor = .yellow
        yellowButton.layer.cornerRadius = 5
        yellowButton.layer.masksToBounds = true
        yellowText.text = NSLocalizedString("_yellow_", comment: "")

        greenButton.backgroundColor = .green
        greenButton.layer.cornerRadius = 5
        greenButton.layer.masksToBounds = true
        greenText.text = NSLocalizedString("_green_", comment: "")

        grayButton.backgroundColor = .gray
        grayButton.layer.cornerRadius = 5
        grayButton.layer.masksToBounds = true
        grayText.text = NSLocalizedString("_gray_", comment: "")

        defaultButton.backgroundColor = NCBrandColor.shared.brandElement
        defaultButton.layer.cornerRadius = 5
        defaultButton.layer.masksToBounds = true
        defaultLabel.text = NSLocalizedString("_default_", comment: "")
    }

    @IBAction func orangeButtonAction(_ sender: UIButton) {
        updateColor(hexColor: UIColor.orange.hexString)
    }

    @IBAction func redButtonAction(_ sender: UIButton) {
        updateColor(hexColor: UIColor.red.hexString)
    }

    @IBAction func violaButtonAction(_ sender: UIButton) {
        updateColor(hexColor: "#8f00ff")
    }

    @IBAction func blueButtonAction(_ sender: UIButton) {
        updateColor(hexColor: UIColor.blue.hexString)
    }

    @IBAction func yellowButtonAction(_ sender: UIButton) {
        updateColor(hexColor: UIColor.yellow.hexString)
    }

    @IBAction func greenButtonAction(_ sender: UIButton) {
        updateColor(hexColor: UIColor.green.hexString)
    }

    @IBAction func grayButtonAction(_ sender: UIButton) {
        updateColor(hexColor: UIColor.gray.hexString)
    }

    @IBAction func defaultButtonAction(_ sender: UIButton) {
        updateColor(hexColor: NCBrandColor.shared.brandElement.hexString)
    }

    func updateColor(hexColor: String?) {
        if let metadata = metadata {
            let serverUrl = metadata.serverUrl + "/" + metadata.fileName
            if NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, colorFolder: hexColor, account: metadata.account) != nil {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced, userInfo: ["serverUrl": metadata.serverUrl])
            }
        }
    }
}

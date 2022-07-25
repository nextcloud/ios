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
    @IBOutlet weak var purpleButton: UIButton!
    @IBOutlet weak var blueButton: UIButton!
    @IBOutlet weak var brownButton: UIButton!
    @IBOutlet weak var greenButton: UIButton!
    @IBOutlet weak var grayButton: UIButton!
    @IBOutlet weak var defaultButton: UIButton!

    @IBOutlet weak var orangeLabel: UILabel!
    @IBOutlet weak var redLabel: UILabel!
    @IBOutlet weak var purpleLabel: UILabel!
    @IBOutlet weak var blueLabel: UILabel!
    @IBOutlet weak var brownLabel: UILabel!
    @IBOutlet weak var greenLabel: UILabel!
    @IBOutlet weak var grayLabel: UILabel!
    @IBOutlet weak var defaultLabel: UILabel!

    var metadata: tableMetadata?
    var tapAction: UITapGestureRecognizer?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = NCBrandColor.shared.secondarySystemBackground
        
        orangeButton.backgroundColor = .orange
        orangeButton.layer.cornerRadius = 5
        orangeButton.layer.masksToBounds = true
        orangeLabel.text = NSLocalizedString("_orange_", comment: "")
        let orangeLabelTapAction = UITapGestureRecognizer(target: self, action: #selector(orangeButtonAction(_:)))
        orangeLabel?.addGestureRecognizer(orangeLabelTapAction)

        redButton.backgroundColor = .red
        redButton.layer.cornerRadius = 5
        redButton.layer.masksToBounds = true
        redLabel.text = NSLocalizedString("_red_", comment: "")
        let redLabelTapAction = UITapGestureRecognizer(target: self, action: #selector(redButtonAction(_:)))
        redLabel?.addGestureRecognizer(redLabelTapAction)

        purpleButton.backgroundColor = .purple
        purpleButton.layer.cornerRadius = 5
        purpleButton.layer.masksToBounds = true
        purpleLabel.text = NSLocalizedString("_purple_", comment: "")
        let purpleLabelTapAction = UITapGestureRecognizer(target: self, action: #selector(purpleButtonAction(_:)))
        purpleLabel?.addGestureRecognizer(purpleLabelTapAction)

        blueButton.backgroundColor = .blue
        blueButton.layer.cornerRadius = 5
        blueButton.layer.masksToBounds = true
        blueLabel.text = NSLocalizedString("_blue_", comment: "")
        let blueLabelTapAction = UITapGestureRecognizer(target: self, action: #selector(blueButtonAction(_:)))
        blueLabel?.addGestureRecognizer(blueLabelTapAction)

        brownButton.backgroundColor = .brown
        brownButton.layer.cornerRadius = 5
        brownButton.layer.masksToBounds = true
        brownLabel.text = NSLocalizedString("_brown_", comment: "")
        let brownLabelTapAction = UITapGestureRecognizer(target: self, action: #selector(brownButtonAction(_:)))
        brownLabel?.addGestureRecognizer(brownLabelTapAction)

        greenButton.backgroundColor = .green
        greenButton.layer.cornerRadius = 5
        greenButton.layer.masksToBounds = true
        greenLabel.text = NSLocalizedString("_green_", comment: "")
        let greenLabelTapAction = UITapGestureRecognizer(target: self, action: #selector(greenButtonAction(_:)))
        greenLabel?.addGestureRecognizer(greenLabelTapAction)

        grayButton.backgroundColor = .gray
        grayButton.layer.cornerRadius = 5
        grayButton.layer.masksToBounds = true
        grayLabel.text = NSLocalizedString("_gray_", comment: "")
        let grayLabelTapAction = UITapGestureRecognizer(target: self, action: #selector(grayButtonAction(_:)))
        grayLabel?.addGestureRecognizer(grayLabelTapAction)

        defaultButton.backgroundColor = NCBrandColor.shared.brandElement
        defaultButton.layer.cornerRadius = 5
        defaultButton.layer.masksToBounds = true
        defaultLabel.text = NSLocalizedString("_default_", comment: "")
        let defaultLabelTapAction = UITapGestureRecognizer(target: self, action: #selector(defaultButtonAction(_:)))
        defaultLabel?.addGestureRecognizer(defaultLabelTapAction)
    }

    @IBAction func orangeButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.orange.hexString)
    }

    @IBAction func redButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.red.hexString)
    }

    @IBAction func purpleButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.purple.hexString)
    }

    @IBAction func blueButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.blue.hexString)
    }

    @IBAction func brownButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.brown.hexString)
    }

    @IBAction func greenButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.green.hexString)
    }

    @IBAction func grayButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.gray.hexString)
    }

    @IBAction func defaultButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: nil)
    }

    func updateColor(hexColor: String?) {
        if let metadata = metadata {
            let serverUrl = metadata.serverUrl + "/" + metadata.fileName
            if NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, colorFolder: hexColor, account: metadata.account) != nil {
                self.dismiss(animated: true)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": metadata.serverUrl])
            }
        }
        self.dismiss(animated: true)
    }
}

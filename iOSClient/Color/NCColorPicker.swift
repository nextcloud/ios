//
//  NCColorPicker.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/07/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
import UIKit

class NCColorPicker: UIViewController {

    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var orangeButton: UIButton!
    @IBOutlet weak var redButton: UIButton!
    @IBOutlet weak var purpleButton: UIButton!
    @IBOutlet weak var blueButton: UIButton!
    @IBOutlet weak var greenButton: UIButton!
    @IBOutlet weak var cyanButton: UIButton!
    @IBOutlet weak var yellowButton: UIButton!
    @IBOutlet weak var grayButton: UIButton!
    @IBOutlet weak var brownButton: UIButton!

    @IBOutlet weak var systemBlueButton: UIButton!
    @IBOutlet weak var systemIndigoButton: UIButton!
    @IBOutlet weak var systemMintButton: UIButton!
    @IBOutlet weak var systemPinkButton: UIButton!

    @IBOutlet weak var defaultButton: UIButton!
    @IBOutlet weak var customButton: UIButton!

    var metadata: tableMetadata?
    var tapAction: UITapGestureRecognizer?
    var selectedColor: UIColor?
    var collectionViewCommon: NCCollectionViewCommon?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .secondarySystemBackground

        if let metadata = metadata {
            let serverUrl = metadata.serverUrl + "/" + metadata.fileName
            if let tableDirectory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrl)), let hex = tableDirectory.colorFolder, let color = UIColor(hex: hex) {
                selectedColor = color
            }
        }

        closeButton.setImage(NCUtility().loadImage(named: "xmark", colors: [NCBrandColor.shared.iconImageColor]), for: .normal)
        titleLabel.text = NSLocalizedString("_select_color_", comment: "")

        orangeButton.backgroundColor = .orange
        orangeButton.layer.cornerRadius = 5
        orangeButton.layer.masksToBounds = true

        redButton.backgroundColor = .red
        redButton.layer.cornerRadius = 5
        redButton.layer.masksToBounds = true

        purpleButton.backgroundColor = .purple
        purpleButton.layer.cornerRadius = 5
        purpleButton.layer.masksToBounds = true

        blueButton.backgroundColor = .blue
        blueButton.layer.cornerRadius = 5
        blueButton.layer.masksToBounds = true

        brownButton.backgroundColor = .brown
        brownButton.layer.cornerRadius = 5
        brownButton.layer.masksToBounds = true

        greenButton.backgroundColor = .green
        greenButton.layer.cornerRadius = 5
        greenButton.layer.masksToBounds = true

        grayButton.backgroundColor = .gray
        grayButton.layer.cornerRadius = 5
        grayButton.layer.masksToBounds = true

        cyanButton.backgroundColor = .cyan
        cyanButton.layer.cornerRadius = 5
        cyanButton.layer.masksToBounds = true

        yellowButton.backgroundColor = .yellow
        yellowButton.layer.cornerRadius = 5
        yellowButton.layer.masksToBounds = true

        systemBlueButton.backgroundColor = .systemBlue
        systemBlueButton.layer.cornerRadius = 5
        systemBlueButton.layer.masksToBounds = true

        systemMintButton.backgroundColor = NCBrandColor.shared.systemMint
        systemMintButton.layer.cornerRadius = 5
        systemMintButton.layer.masksToBounds = true

        systemPinkButton.backgroundColor = .systemPink
        systemPinkButton.layer.cornerRadius = 5
        systemPinkButton.layer.masksToBounds = true

        customButton.setImage(UIImage(named: "rgb"), for: .normal)
        if let selectedColor = selectedColor {
            customButton.backgroundColor = selectedColor
        } else {
            customButton.backgroundColor = .secondarySystemBackground
        }
        customButton.layer.cornerRadius = 5
        customButton.layer.masksToBounds = true

        systemIndigoButton.backgroundColor = .systemIndigo
        systemIndigoButton.layer.cornerRadius = 5
        systemIndigoButton.layer.masksToBounds = true

        defaultButton.backgroundColor = NCBrandColor.shared.customer
        defaultButton.layer.cornerRadius = 5
        defaultButton.layer.masksToBounds = true
    }

    // MARK: - Action

    @IBAction func closeAction(_ sender: UIButton) {
        dismiss(animated: true)
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

    @IBAction func greenButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.green.hexString)
    }

    @IBAction func cyanButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.cyan.hexString)
    }

    @IBAction func yellowButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.yellow.hexString)
    }

    @IBAction func grayButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.gray.hexString)
    }

    @IBAction func brownButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.brown.hexString)
    }

    @IBAction func systemBlueButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.systemBlue.hexString)
    }

    @IBAction func systemIndigoButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.systemIndigo.hexString)
    }

    @IBAction func systemMintButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: NCBrandColor.shared.systemMint.hexString)
    }

    @IBAction func systemPinkButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: UIColor.systemPink.hexString)
    }

    @IBAction func defaultButtonAction(_ sender: AnyObject) {
        updateColor(hexColor: nil)
    }

    @IBAction func customButtonAction(_ sender: AnyObject) {

        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.supportsAlpha = false
        if let selectedColor = selectedColor {
            picker.selectedColor = selectedColor
        }
        self.present(picker, animated: true, completion: nil)
    }

    // MARK: -

    func updateColor(hexColor: String?) {
        if let metadata = metadata {
            let serverUrl = metadata.serverUrl + "/" + metadata.fileName
            NCManageDatabase.shared.updateDirectoryColorFolder(hexColor, metadata: metadata, serverUrl: serverUrl)
            self.collectionViewCommon?.collectionView.reloadData()
            self.dismiss(animated: true)
        }
        self.dismiss(animated: true)
    }
}

extension NCColorPicker: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        let hexColor = viewController.selectedColor.hexString
        updateColor(hexColor: hexColor)
    }
}

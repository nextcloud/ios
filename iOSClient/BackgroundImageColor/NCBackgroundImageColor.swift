//
//  NCBackgroundImageColor.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/05/21.
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

import UIKit
import ChromaColorPicker

class NCBackgroundImageColor: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var chromaColorPickerView: UIView!
    
    @IBOutlet weak var darkmodeLabel: UILabel!
    @IBOutlet weak var darkmodeSwitch: UISwitch!
    
    @IBOutlet weak var useForAllLabel: UILabel!
    @IBOutlet weak var useForAllSwitch: UISwitch!

    @IBOutlet weak var defaultButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var okButton: UIButton!
    
    private let colorPicker = ChromaColorPicker()
    private let brightnessSlider = ChromaBrightnessSlider()
    private var colorHandle: ChromaColorHandle?
    private let defaultColorPickerSize = CGSize(width: 200, height: 200)
    private let brightnessSliderWidthHeightRatio: CGFloat = 0.1
    
    private var darkColor = ""      // "#000000"
    private var lightColor = ""     // #FFFFFF
    
    public var collectionViewCommon: NCCollectionViewCommon?

    let width: CGFloat = 300
    let height: CGFloat = 500
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupColorPicker()
        setupBrightnessSlider()
        setupColorPickerHandles()
        
        titleLabel.text = NSLocalizedString("_background_", comment: "")
        darkmodeLabel.text = NSLocalizedString("_dark_mode_", comment: "")
        useForAllLabel.text = NSLocalizedString("_default_color_all_folders_", comment: "")

        defaultButton.setTitle(NSLocalizedString("_default_color_", comment: ""), for: .normal)

        cancelButton.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        okButton.setTitle(NSLocalizedString("_ok_", comment: ""), for: .normal)
        
        defaultButton.layer.cornerRadius = 10
        defaultButton.layer.borderWidth = 0.5
        defaultButton.layer.borderColor = UIColor.gray.cgColor
        defaultButton.layer.masksToBounds = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if traitCollection.userInterfaceStyle == .dark {
            darkmodeSwitch.isOn = true
        } else {
            darkmodeSwitch.isOn = false
        }
        useForAllSwitch.isOn = false
        
        // Color for this view
        if let collectionViewCommon = collectionViewCommon {
            let layoutForView = NCUtility.shared.getLayoutForView(key: collectionViewCommon.layoutKey, serverUrl: collectionViewCommon.serverUrl)
            darkColor = layoutForView.darkColorBackground
            lightColor = layoutForView.lightColorBackground
        }
                
        // Color for all folders
        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            if darkColor == "" {
                darkColor = activeAccount.darkColorFiles
            }
            if lightColor == "" {
                lightColor = activeAccount.lightColorFiles
            }
        }
       
        // set color
        if darkmodeSwitch.isOn {
            if let color = UIColor.init(hex: darkColor) {
                changeColor(color)
            } else {
                changeColor(.black)
            }
        } else {
            if let color = UIColor.init(hex: lightColor) {
                changeColor(color)
            } else {
                changeColor(.white)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - Action
    
    @IBAction func darkmodeAction(_ sender: UISwitch) {
                
        if sender.isOn {
            if darkColor == "" {
                changeColor(.black)
            } else {
                if let color = UIColor.init(hex: darkColor) {
                    changeColor(color)
                }
            }
        } else {
            if lightColor == "" {
                changeColor(.white)
            } else {
                if let color = UIColor.init(hex: lightColor) {
                    changeColor(color)
                }
            }
        }
    }
    
    @IBAction func defaultAction(_ sender: Any) {
        
        darkColor = ""
        lightColor = ""
        
        if darkmodeSwitch.isOn {
            changeColor(.black)
        } else {
            changeColor(.white)
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        collectionViewCommon?.setLayout()
        dismiss(animated: true)
    }
    
    @IBAction func okAction(_ sender: Any) {
        
        if useForAllSwitch.isOn {
            NCManageDatabase.shared.setAccountColorFiles(lightColorFiles: lightColor, darkColorFiles: darkColor)
        } else {
            if let collectionViewCommon = collectionViewCommon {
                NCUtility.shared.setBackgroundColorForView(key: collectionViewCommon.layoutKey, serverUrl: collectionViewCommon.serverUrl, lightColorBackground: lightColor, darkColorBackground: darkColor)
            }
        }
        
        collectionViewCommon?.setLayout()
        dismiss(animated: true)
    }
    
    // MARK: - ChromaColorPicker
    
    private func setupColorPicker() {
        colorPicker.delegate = self
        colorPicker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(colorPicker)

        NSLayoutConstraint.activate([
            colorPicker.centerXAnchor.constraint(equalTo: chromaColorPickerView.centerXAnchor),
            colorPicker.topAnchor.constraint(equalTo: chromaColorPickerView.topAnchor),
            colorPicker.widthAnchor.constraint(equalToConstant: defaultColorPickerSize.width),
            colorPicker.heightAnchor.constraint(equalToConstant: defaultColorPickerSize.height)
        ])
    }
    
    private func setupBrightnessSlider() {
        brightnessSlider.connect(to: colorPicker)
        
        // Style
        brightnessSlider.trackColor = UIColor.blue
        brightnessSlider.handle.borderWidth = 3.0 // Example of customizing the handle's properties.
        
        // Layout
        brightnessSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(brightnessSlider)
        
        NSLayoutConstraint.activate([
            brightnessSlider.centerXAnchor.constraint(equalTo: colorPicker.centerXAnchor),
            brightnessSlider.topAnchor.constraint(equalTo: colorPicker.bottomAnchor, constant: 20),
            brightnessSlider.widthAnchor.constraint(equalTo: colorPicker.widthAnchor, multiplier: 1),
            brightnessSlider.heightAnchor.constraint(equalTo: brightnessSlider.widthAnchor, multiplier: brightnessSliderWidthHeightRatio)
        ])
    }
    
    private func setupColorPickerHandles() {
        colorHandle = colorPicker.addHandle(at: collectionViewCommon?.collectionView.backgroundColor)
    }
    
    private func changeColor(_ color: UIColor) {
        
        colorHandle?.color = color
        colorPicker.setNeedsLayout()
        brightnessSlider.trackColor = color
        collectionViewCommon?.collectionView.backgroundColor = color
    }
}

extension NCBackgroundImageColor: ChromaColorPickerDelegate {
    func colorPickerHandleDidChange(_ colorPicker: ChromaColorPicker, handle: ChromaColorHandle, to color: UIColor) {
        
        if darkmodeSwitch.isOn {
            darkColor = color.hexString
        } else {
            lightColor = color.hexString
        }
        
        collectionViewCommon?.collectionView.backgroundColor = color
    }
}

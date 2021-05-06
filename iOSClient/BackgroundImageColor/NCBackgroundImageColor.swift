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
    
    @IBOutlet weak var whiteButton: UIButton!
    @IBOutlet weak var orangeButton: UIButton!
    @IBOutlet weak var redButton: UIButton!
    @IBOutlet weak var greenButton: UIButton!
    @IBOutlet weak var blackButton: UIButton!

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
    
    private var darkColor = ""
    private var lightColor = ""
    
    public var collectionViewCommon: NCCollectionViewCommon?

    let width: CGFloat = 300
    let height: CGFloat = 485
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupColorPicker()
        setupBrightnessSlider()
        setupColorPickerHandles()
        
        titleLabel.text = NSLocalizedString("_background_", comment: "")
        darkmodeLabel.text = NSLocalizedString("_dark_mode_", comment: "")
        useForAllLabel.text = NSLocalizedString("_as_default_color_", comment: "")

        defaultButton.setTitle(NSLocalizedString("_default_color_", comment: ""), for: .normal)

        cancelButton.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        okButton.setTitle(NSLocalizedString("_ok_", comment: ""), for: .normal)
        
        whiteButton.backgroundColor = .white
        whiteButton.layer.cornerRadius = 5
        whiteButton.layer.borderWidth = 0.5
        whiteButton.layer.borderColor = NCBrandColor.shared.label.cgColor
        whiteButton.layer.masksToBounds = true

        orangeButton.backgroundColor = .orange
        orangeButton.layer.cornerRadius = 5
        orangeButton.layer.borderWidth = 0.5
        orangeButton.layer.borderColor = NCBrandColor.shared.label.cgColor
        orangeButton.layer.masksToBounds = true
       
        redButton.backgroundColor = .red
        redButton.layer.cornerRadius = 5
        redButton.layer.borderWidth = 0.5
        redButton.layer.borderColor = NCBrandColor.shared.label.cgColor
        redButton.layer.masksToBounds = true
        
        greenButton.backgroundColor = .green
        greenButton.layer.cornerRadius = 5
        greenButton.layer.borderWidth = 0.5
        greenButton.layer.borderColor = NCBrandColor.shared.label.cgColor
        greenButton.layer.masksToBounds = true
        
        blackButton.backgroundColor = .black
        blackButton.layer.cornerRadius = 5
        blackButton.layer.borderWidth = 0.5
        blackButton.layer.borderColor = NCBrandColor.shared.label.cgColor
        blackButton.layer.masksToBounds = true
        
        defaultButton.layer.cornerRadius = 15
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
                darkColor = activeAccount.darkColorBackground
            }
            if lightColor == "" {
                lightColor = activeAccount.lightColorBackground
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
    
    @IBAction func whiteButtonAction(_ sender: UIButton) {
        changeColor(.white)
    }
    
    @IBAction func orangeButtonAction(_ sender: UIButton) {
        changeColor(.orange)
    }
    
    @IBAction func redButtonAction(_ sender: UIButton) {
        changeColor(.red)
    }
    
    @IBAction func greenButtonAction(_ sender: UIButton) {
        changeColor(.green)
    }
    
    @IBAction func blackButtonAction(_ sender: UIButton) {
        changeColor(.black)
    }
    
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
        
        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            if darkmodeSwitch.isOn {
                if useForAllSwitch.isOn {
                    darkColor = ""
                    changeColor(.black)
                } else {
                    if let color = UIColor.init(hex: activeAccount.darkColorBackground) {
                        darkColor = activeAccount.darkColorBackground
                        changeColor(color)
                    } else {
                        darkColor = ""
                        changeColor(.black)
                    }
                }
            } else {
                if useForAllSwitch.isOn {
                    lightColor = "#FFFFFF"
                    changeColor(.white)
                } else {
                    if let color = UIColor.init(hex:  activeAccount.lightColorBackground) {
                        lightColor = activeAccount.lightColorBackground
                        changeColor(color)
                    } else {
                        lightColor = "#FFFFFF"
                        changeColor(.white)
                    }
                }
            }
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        collectionViewCommon?.setLayout()
        dismiss(animated: true)
    }
    
    @IBAction func okAction(_ sender: Any) {
        
        var lightColor = self.lightColor
        var darkColor = self.darkColor
        
        if lightColor == "#FFFFFF" { lightColor = "" }
        if darkColor == "#000000" { darkColor = "" }

        if let collectionViewCommon = collectionViewCommon {
            if useForAllSwitch.isOn {
                NCManageDatabase.shared.setAccountColorFiles(lightColorBackground: lightColor, darkColorBackground: darkColor)
                NCUtility.shared.setBackgroundColorForView(key: collectionViewCommon.layoutKey, serverUrl: collectionViewCommon.serverUrl, lightColorBackground: "", darkColorBackground: "")
            } else {
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
            colorPicker.leadingAnchor.constraint(equalTo: chromaColorPickerView.leadingAnchor, constant: 20),
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
        
        if darkmodeSwitch.isOn {
            darkColor = color.hexString
        } else {
            lightColor = color.hexString
        }
        
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

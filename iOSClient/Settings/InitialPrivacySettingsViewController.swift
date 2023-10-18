//
//  InitialPrivacySettingsViewController.swift
//  Nextcloud
//
//  Created by A200073704 on 25/04/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import AppTrackingTransparency
import AdSupport
import UIKit

class InitialPrivacySettingsViewController: UIViewController {
    
    @IBOutlet weak var dataPrivacyImage: UIImageView!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var privacySettingsHelpText: UITextView!
    @IBOutlet weak var privacySettingsTitle: UILabel!
    @IBOutlet weak var widthPriavacyHelpView: NSLayoutConstraint!
    var privacyHelpText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        privacySettingsTitle.text = NSLocalizedString("_privacy_settings_title_", comment: "")
        privacyHelpText = NSLocalizedString("_privacy_help_text_after_login_", comment: "")
        privacySettingsHelpText.text = privacyHelpText
        dataPrivacyImage.image = UIImage(named: "dataPrivacy")!.image(color: NCBrandColor.shared.brand, size: 60)
        privacySettingsHelpText.delegate = self
        privacySettingsHelpText.textColor = .label
        privacySettingsHelpText.hyperLink(originalText: privacyHelpText,
                                          linkTextsAndTypes: [NSLocalizedString("_key_privacy_help_", comment: ""): LinkType.privacyPolicy.rawValue,
                                                              NSLocalizedString("_key_reject_help_", comment: ""): LinkType.reject.rawValue,
                                                              NSLocalizedString("_key_settings_help_", comment: ""): LinkType.settings.rawValue])
        
        acceptButton.backgroundColor = NCBrandColor.shared.brand
        acceptButton.tintColor = UIColor.white
        acceptButton.layer.cornerRadius = 5
        acceptButton.layer.borderWidth = 1
        acceptButton.layer.borderColor = NCBrandColor.shared.brand.cgColor
        acceptButton.setTitle(NSLocalizedString("_accept_button_title_", comment: ""), for: .normal)
        privacySettingsHelpText.centerText()
        privacySettingsHelpText.font = UIFont(name: privacySettingsHelpText.font!.fontName, size: 16)
        self.navigationItem.leftBarButtonItem?.tintColor = NCBrandColor.shared.brand
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.navigationController?.navigationBar.isHidden = false
    }
    
    override func viewDidLayoutSubviews(){
        if UIDevice.current.userInterfaceIdiom == .pad {
            widthPriavacyHelpView.constant = UIScreen.main.bounds.width - 100
        }
    }
    
    @IBAction func onAcceptButtonClicked(_ sender: Any) {
        requestPermission()
    }
    
    //NEWLY ADDED PERMISSIONS FOR iOS 14
    func requestPermission() {
        UserDefaults.standard.set(true, forKey: "isInitialPrivacySettingsShowed")
        UserDefaults.standard.set(true, forKey: "isAnalysisDataCollectionSwitchOn")
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    // Tracking authorization dialog was shown
                    // and we are authorized
                    print("Authorized")
                    // Now that we are authorized we can get the IDFA
                    print(ASIdentifierManager.shared().advertisingIdentifier)
                case .denied:
                    UserDefaults.standard.set(true, forKey: "isInitialPrivacySettingsShowed")
                    UserDefaults.standard.set(false, forKey: "isAnalysisDataCollectionSwitchOn")
                    print("Denied")
                case .notDetermined:
                    // Tracking authorization dialog has not been shown
                    print("Not Determined")
                case .restricted:
                    print("Restricted")
                @unknown default:
                    print("Unknown")
                }
            }
        } else {
            UserDefaults.standard.set(true, forKey: "isInitialPrivacySettingsShowed")
            UserDefaults.standard.set(true, forKey: "isAnalysisDataCollectionSwitchOn")
        }
        self.dismiss(animated: true, completion: nil)
    }
}
// MARK: - UITextViewDelegate
extension InitialPrivacySettingsViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        if let linkType = LinkType(rawValue: URL.absoluteString) {
            // TODO: handle linktype here with switch or similar.
            switch linkType {
            case LinkType.privacyPolicy:
                //let storyBoard: UIStoryboard = UIStoryboard(name: "NCSettings", bundle: nil)
                let privacyViewController = PrivacyPolicyViewController()
                self.navigationController?.pushViewController(privacyViewController, animated: true)
            case LinkType.reject:
                UserDefaults.standard.set(false, forKey: "isAnalysisDataCollectionSwitchOn")
                UserDefaults.standard.set(true, forKey: "isInitialPrivacySettingsShowed")
                self.dismiss(animated: true, completion: nil)
            case LinkType.settings:
                let privacySettingsViewController = PrivacySettingsViewController()
                UserDefaults.standard.set(true, forKey: "showSettingsButton")
                self.navigationController?.pushViewController(privacySettingsViewController, animated: true)
            }
            print("handle link:: \(linkType)")
        }
        return false
    }
}

public extension UITextView {
    
    func hyperLink(originalText: String, linkTextsAndTypes: [String: String]) {
        
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        
        let attributedOriginalText = NSMutableAttributedString(string: originalText)
        
        let fullRange = NSRange(location: 0, length: attributedOriginalText.length)
        attributedOriginalText.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.label, range: fullRange)
        for linkTextAndType in linkTextsAndTypes {
            let linkRange = attributedOriginalText.mutableString.range(of: linkTextAndType.key)
            attributedOriginalText.addAttribute(NSAttributedString.Key.link, value: linkTextAndType.value, range: linkRange)
            attributedOriginalText.addAttribute(NSAttributedString.Key.paragraphStyle, value: style, range: fullRange)
            attributedOriginalText.addAttribute(NSAttributedString.Key.foregroundColor, value: NCBrandColor.shared.brand, range: linkRange)
            attributedOriginalText.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 10), range: fullRange)
        }
        
        self.linkTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.shared.brand]
        self.attributedText = attributedOriginalText
    }
    
    func centerText() {
        self.textAlignment = .justified
        let fittingSize = CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
        let size = sizeThatFits(fittingSize)
        let topOffset = (bounds.size.height - size.height * zoomScale) / 2
        let positiveTopOffset = max(1, topOffset)
        contentOffset.y = -positiveTopOffset
    }
}

enum LinkType: String {
    case reject
    case privacyPolicy
    case settings
}



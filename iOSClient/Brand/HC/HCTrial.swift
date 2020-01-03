//
//  HCTrial.swift
//  HandwerkCloud
//
//  Created by Marino Faggiana on 28/04/2019.
//  Copyright © 2019 TWS. All rights reserved.
//

import Foundation

class HCTrial: UIViewController {
    
    @objc var account: tableAccount?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var viewLogo: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var imageTimer: UIImageView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var purchaseButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var purchaseLeadingConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let language = Locale.current.languageCode

        view.backgroundColor = NCBrandColor.sharedInstance.brand
        viewLogo.backgroundColor = NCBrandColor.sharedInstance.brand
        //titleLabel.text = "HANDWERKCLOUD TRIAL"
        
        purchaseButton.layer.cornerRadius = 20
        purchaseButton.clipsToBounds = true
        purchaseButton.backgroundColor = UIColor.white //NCBrandColor.sharedInstance.brand
        purchaseButton.setTitleColor(NCBrandColor.sharedInstance.brand, for: .normal)

        purchaseButton.setTitle(NSLocalizedString("_purchase_", comment: ""), for: UIControl.State.normal)
        
        continueButton.layer.cornerRadius = 20
        continueButton.clipsToBounds = true
        continueButton.layer.borderWidth = 1
        continueButton.layer.borderColor = UIColor.white.cgColor //NCBrandColor.sharedInstance.brand.cgColor
        continueButton.backgroundColor = .clear
        continueButton.setTitle(NSLocalizedString("_continue_", comment: ""), for: UIControl.State.normal)
        
        guard let account = account else {
            return
        }
        
        // Expired
        
        if account.hcNextGroupExpirationGroupExpired || account.hcTrialExpired {
            
            //let numberOfDays: Int = Int(account.hcAccountRemoveRemainingSec) / (24*3600)
            
            imageTimer.image = CCGraphics.changeThemingColorImage(UIImage(named: "timeroff"), width: 200, height: 200, color: .white)!
            continueButton.isHidden = true
            purchaseLeadingConstraint.constant = (self.view.bounds.width/2) - 75
            
            if language == "de" {
                textView.text = "Vielen Dank, dass Sie sich für HandwerkCloud entschieden haben. Ihr Testzeitraum ist abgelaufen. Um HandwerkCloud weiterhin nutzen zu können, tippen Sie auf \"Kaufen\" oder besuchen Sie unsere Webseite."
                //\n\nYot have \(numberOfDays) days remaining before your account and files are removed from HadwerkCloud."
            } else if language == "it" {
                textView.text = "Grazie per aver provato HandwerkCloud, il tuo periodo di prova è scaduto.\n\nPer continuare a utilizzare HandwerkCloud tocca il pulsante di acquisto o visita il sito Web."
                //\n\nYot have \(numberOfDays) giorni rimanenti prima che il tuo account e i tuoi file siano rimossi da HadwerkCloud."
            } else {
                textView.text = "Thank you for trying HandwerkCloud, your trial has now expired.\n\nTo continue using HandwerkCloud tap the purchase button or visit the website."
                //\n\nYot have \(numberOfDays) days remaining before your account and files are removed from HadwerkCloud."
            }
        }
        
        // Trial
        
        else if account.hcIsTrial {
            
            let numberOfDays: Int = Int(account.hcTrialRemainingSec) / (24*3600)
            
            imageTimer.image = CCGraphics.changeThemingColorImage(UIImage(named: "timer"), width: 200, height: 200, color: .white)!
            textView.textAlignment = NSTextAlignment.center
            purchaseLeadingConstraint.constant = 20
            
            if language == "de" {
                if numberOfDays > 1 {
                    textView.text = "Ihr Testzeitraum läuft in \(numberOfDays) Tagen ab."
                } else {
                    textView.text = "Ihr Testzeitraum läuft in 1 Tag ab."
                }
            } else if language == "it" {
                if numberOfDays > 1 {
                    textView.text = "Hai ancora \(numberOfDays) giorni rimasti di prova."
                } else {
                    textView.text = "Hai ancora 1 giorno rimasto di prova."
                }
            } else {
                if numberOfDays > 1 {
                    textView.text = "Yot have \(numberOfDays) days left in your trial."
                } else {
                    textView.text = "Yot have 1 day left in your trial."
                }
            }
        }
        
        
    }
    
    @IBAction func purchaseButtonTapped(_ sender: AnyObject) {

        guard let capabilities = NCManageDatabase.sharedInstance.getCapabilites(account: appDelegate.activeAccount) else {
            return
        }
        
        if let url = URL(string: capabilities.HCShopUrl) {
            UIApplication.shared.open(url, options: [:])
        }

        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func continueButtonTapped(_ sender: AnyObject) {
        dismiss(animated: true, completion: nil)
    }
}

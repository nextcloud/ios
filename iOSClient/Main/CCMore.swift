//
//  CCMore.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class CCMore: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var themingBackground: UIImageView!
    @IBOutlet weak var themingAvatar: UIImageView!
    @IBOutlet weak var labelUsername: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var labelQuota: UILabel!
    @IBOutlet weak var labelQuotaExternalSite: UILabel!
    @IBOutlet weak var progressQuota: UIProgressView!

    var functionMenu = [OCExternalSites]()
    var settingsMenu = [OCExternalSites]()
    var quotaMenu = [OCExternalSites]()

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var menuExternalSite: [tableExternalSites]?
    var tableAccont : TableAccount?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.separatorColor = NCBrandColor.sharedInstance.seperator
        
        themingBackground.image = UIImage.init(named: "themingBackground")
        
        // create tap gesture recognizer
        let tapQuota = UITapGestureRecognizer(target: self, action: #selector(tapLabelQuotaExternalSite))
        labelQuotaExternalSite.isUserInteractionEnabled = true
        labelQuotaExternalSite.addGestureRecognizer(tapQuota)
        
        let tapImageLogo = UITapGestureRecognizer(target: self, action: #selector(tapImageLogoManageAccount))
        themingBackground.isUserInteractionEnabled = true
        themingBackground.addGestureRecognizer(tapImageLogo)
        
        // Notification
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeUserProfile), name: NSNotification.Name(rawValue: "changeUserProfile"), object: nil)
    }
    
    // Apparirà
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        // Clear
        functionMenu.removeAll()
        settingsMenu.removeAll()
        quotaMenu.removeAll()
        labelQuotaExternalSite.text = ""
        
        // Internal
        var item = OCExternalSites.init()
        item.name = "_transfers_"
        item.icon = "moreTransfers"
        item.url = "segueTransfers"
        functionMenu.append(item)
        
        item = OCExternalSites.init()
        if NCBrandOptions.sharedInstance.use_recent_activity_title == true {
            item.name = "_recent_activity_"
        } else {
            item.name = "_activity_"
        }
        
        item.icon = "moreActivity"
        item.url = "segueActivity"
        functionMenu.append(item)
        
        item = OCExternalSites.init()
        item.name = "_local_storage_"
        item.icon = "moreLocalStorage"
        item.url = "segueLocalStorage"
        functionMenu.append(item)
        
        item = OCExternalSites.init()
        item.name = "_settings_"
        item.icon = "moreSettings"
        item.url = "segueSettings"
        settingsMenu.append(item)

        // External 
        menuExternalSite = NCManageDatabase.sharedInstance.getAllExternalSitesWithPredicate(NSPredicate(format: "(account == '\(appDelegate.activeAccount!)')"))
        
        for table in menuExternalSite! {
            
            item = OCExternalSites.init()
            
            item.name = table.name
            item.url = table.url
            item.icon = table.icon
            
            if (table.type == "link") {
                item.icon = "moreExternalSite"
                functionMenu.append(item)
            }
            if (table.type == "settings") {
                item.icon = "moreSettingsExternalSite"
                settingsMenu.append(item)
            }
            if (table.type == "quota") {
                quotaMenu.append(item)
            }
        }
        
        if (quotaMenu.count > 0) {
            
            let item = quotaMenu[0]
            labelQuotaExternalSite.text = item.name
        }
        
        // User data & Theming
        changeUserProfile()
        changeTheming()
        
        // Title
        self.navigationItem.title = NSLocalizedString("_more_", comment: "")
        
        // Aspect
        appDelegate.aspectNavigationControllerBar(self.navigationController?.navigationBar, encrypted: false, online: appDelegate.reachability.isReachable(), hidden: false)
        appDelegate.aspectTabBar(self.tabBarController?.tabBar, hidden: false)

        // +
        appDelegate.plusButtonVisibile(true)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    func changeTheming() {
        
        // Theming Background
        let theminBackgroundFile = UIImage.init(contentsOfFile: "\(appDelegate.directoryUser!)/themingBackground.png")
        if (theminBackgroundFile != nil) {
            themingBackground.image = theminBackgroundFile
        } else {
            themingBackground.image = UIImage.init(named: "themingBackground")
        }

        if (self.isViewLoaded && (self.view.window != nil)) {
            appDelegate.changeTheming(self)
        }
    }
    
    func changeUserProfile() {
     
        let themingAvatarFile : UIImage? = UIImage.init(contentsOfFile: "\(appDelegate.directoryUser!)/avatar.png")
        
        if (themingAvatarFile != nil) {
            
            themingAvatar.image = themingAvatarFile
            
        } else {
            
            themingAvatar.image = UIImage.init(named: "moreAvatar")
        }
        
        // Display Name user & Quota
        tableAccont = CCCoreData.getActiveAccount()
        if (tableAccont != nil) {
            
            if let displayName = self.tableAccont!.displayName {
                if displayName.isEmpty {
                    labelUsername.text = self.tableAccont!.user
                }
                else{
                    labelUsername.text = self.tableAccont!.displayName
                }
            }
            else{
                labelUsername.text = self.tableAccont!.user
            }
            
            // fix CCMore.swift line 208 Version 2.17.2 (00005)
            if (self.tableAccont?.quotaRelative != nil && self.tableAccont?.quotaTotal != nil && self.tableAccont?.quotaUsed != nil) {
                
                progressQuota.progress = Float((self.tableAccont?.quotaRelative)!) / 100
                progressQuota.progressTintColor = NCBrandColor.sharedInstance.brand
                
                let quota : String = CCUtility.transformedSize(Double((self.tableAccont?.quotaTotal)!))
                let quotaUsed : String = CCUtility.transformedSize(Double((self.tableAccont?.quotaUsed)!))
                
                labelQuota.text = String.localizedStringWithFormat(NSLocalizedString("_quota_using_", comment: ""), quotaUsed, quota)
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 2
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if (section == 0) {
            return 10
        } else {
            return 30
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var cont = 0
        
        // Menu Normal
        if (section == 0) {
            cont = functionMenu.count
        }
        // Menu Settings
        if (section == 1) {
            cont = settingsMenu.count
        }
        
        return cont
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! CCCellMore

        // change color selection and disclosure indicator
        let selectionColor : UIView = UIView.init()
        selectionColor.backgroundColor = NCBrandColor.sharedInstance.getColorSelectBackgrond()
        cell.selectedBackgroundView = selectionColor
        
        cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        
        // Menu Normal
        if (indexPath.section == 0) {
            
            let item = functionMenu[indexPath.row]
            
            cell.imageIcon?.image = UIImage.init(named: item.icon)
            cell.labelText?.text = NSLocalizedString(item.name, comment: "")
            cell.labelText.textColor = NCBrandColor.sharedInstance.moreNormal

        }
        
        // Menu Settings
        if (indexPath.section == 1) {
            
            let item = settingsMenu[indexPath.row]
            
            cell.imageIcon?.image = UIImage.init(named: item.icon)
            cell.labelText?.text = NSLocalizedString(item.name, comment: "")
            cell.labelText.textColor = NCBrandColor.sharedInstance.moreSettings
        }
        
        return cell
    }

    // method to run when table view cell is tapped
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        var item: OCExternalSites = OCExternalSites.init()
        
        // Menu Function
        if (indexPath.section == 0) {
            
            item = functionMenu[indexPath.row]
        }
        
        // Menu Settings
        if (indexPath.section == 1) {
            
            item = settingsMenu[indexPath.row]
        }
        
        if (item.url.contains("segue") && !item.url.contains("//")) {
            
            self.navigationController?.performSegue(withIdentifier: item.url, sender: self)
        }
        
        if (item.url.contains("//")) {
            
            if (self.splitViewController?.isCollapsed)! {
                
                let webVC = SwiftWebVC(urlString: item.url)
                self.navigationController?.pushViewController(webVC, animated: true)
                self.navigationController?.navigationBar.isHidden = false
                
            } else {
                
                let webVC = SwiftModalWebVC(urlString: item.url)
                self.present(webVC, animated: true, completion: nil)
            }
        }
    }
    
    func tapLabelQuotaExternalSite() {
        
        if (quotaMenu.count > 0) {
            
            let item = quotaMenu[0]
            
            if (self.splitViewController?.isCollapsed)! {
                
                let webVC = SwiftWebVC(urlString: item.url)
                self.navigationController?.pushViewController(webVC, animated: true)
                self.navigationController?.navigationBar.isHidden = false
                
            } else {
                
                let webVC = SwiftModalWebVC(urlString: item.url)
                self.present(webVC, animated: true, completion: nil)
            }
        }
    }
    
    func tapImageLogoManageAccount() {
        
        let controller = CCManageAccount.init()
        
        self.navigationController?.pushViewController(controller, animated: true)
    }

}

class CCCellMore: UITableViewCell {
    
    @IBOutlet weak var labelText: UILabel!
    @IBOutlet weak var imageIcon: UIImageView!
}

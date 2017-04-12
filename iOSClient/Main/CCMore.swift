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

    @IBOutlet weak var imageLogo: UIImageView!
    @IBOutlet weak var imageAvatar: UIImageView!
    @IBOutlet weak var labelUsername: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var labelQuota: UILabel!
    @IBOutlet weak var progressQuota: UIProgressView!

    var normalMenu: [OCExternalSites]!
    var settingsMenu: [OCExternalSites]!
    var quotaMenu: [OCExternalSites]!
    
    let itemsMenuLabelText = [["_transfers_","_activity_","_local_storage_"], ["_settings_"]]
    let itemsMenuImage = [["moreTransfers","moreActivity","moreLocalStorage"], ["moreSettings"]]
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var menuExternalSite: [TableExternalSites]?
    var tableAccont : TableAccount?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.imageLogo.image = UIImage.init(named: image_brandLogoMenu)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        self.menuExternalSite = CCCoreData.getAllTableExternalSites(with:  NSPredicate(format: "(account == '\(appDelegate.activeAccount!)')")) as? [TableExternalSites]
        
        
        self.tableAccont = CCCoreData.getActiveAccount()
        if (self.tableAccont != nil) {
        
            self.labelUsername.text = self.tableAccont?.user
            self.progressQuota.progress = Float((self.tableAccont?.quotaRelative)!) / 100
        
            let quota : String = CCUtility.transformedSize(Double((self.tableAccont?.quotaTotal)!))
            let quotaUsed : String = CCUtility.transformedSize(Double((self.tableAccont?.quotaUsed)!))
        
            self.labelQuota.text = String.localizedStringWithFormat(NSLocalizedString("_quota_using_", comment: ""), quotaUsed, quota)
        }
        
        // Avatar
        let avatar : UIImage? = UIImage.init(contentsOfFile: "\(appDelegate.directoryUser!)/avatar.png")
        
        if (avatar != nil) {
        
            self.imageAvatar.image = avatar
            
        } else {
            
            self.imageAvatar.image = UIImage.init(named: "moreAvatar")
        }
        
        // Aspect
        CCAspect.aspectNavigationControllerBar(self.navigationController?.navigationBar, encrypted: false, online: appDelegate.reachability.isReachable(), hidden: true)
        CCAspect.aspectTabBar(self.tabBarController?.tabBar, hidden: false)

        tableView.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        if (self.menuExternalSite == nil) {
            return 2
        } else {
            return 3
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if (section == 0) {
            return 10
        } else {
            return 30
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // Menu Function
        if (section == 0) {
            return self.itemsMenuLabelText[0].count
        }
        // Menu External Site
        if (section == 1 && self.menuExternalSite != nil) {
            return (self.menuExternalSite?.count)!
        }
        // Menu Settings
        if ((section == 1 && self.menuExternalSite == nil) || (section == 2 && self.menuExternalSite != nil)) {
            return self.itemsMenuLabelText[1].count
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! CCCellMore

        // change color selection
        let selectionColor : UIView = UIView.init()
        selectionColor.backgroundColor = Constant.GlobalConstants.k_Color_SelectBackgrond
        cell.selectedBackgroundView = selectionColor
        
        // Menu Function
        if (indexPath.section == 0) {
            
            cell.imageIcon?.image = UIImage.init(named: self.itemsMenuImage[0][indexPath.row])
            cell.labelText?.text = NSLocalizedString(self.itemsMenuLabelText[0][indexPath.row], comment: "")
            cell.labelText.textColor = Constant.GlobalConstants.k_Color_Nextcloud
        }
        // Menu External Site
        if (indexPath.section == 1 && self.menuExternalSite != nil) {
            
            cell.imageIcon?.image = UIImage.init(named: "moreExternalSite")
            let externalSite : TableExternalSites = self.menuExternalSite![indexPath.row]
            cell.labelText?.text = externalSite.name
            cell.labelText.textColor = .black
        }
        // Menu Settings
        if ((indexPath.section == 1 && self.menuExternalSite == nil) || (indexPath.section == 2 && self.menuExternalSite != nil)) {
            
            cell.imageIcon?.image = UIImage.init(named: self.itemsMenuImage[1][indexPath.row])
            cell.labelText?.text = NSLocalizedString(self.itemsMenuLabelText[1][indexPath.row], comment: "")
            cell.labelText.textColor = Constant.GlobalConstants.k_Color_GrayMenuMore
        }
        
        return cell
    }

    // method to run when table view cell is tapped
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Menu Function
        if (indexPath.section == 0) {
            
            if (indexPath.row == 0) {
                self.navigationController?.performSegue(withIdentifier: "segueTransfers", sender: self)
            }
            if (indexPath.row == 1) {
                self.navigationController?.performSegue(withIdentifier: "segueActivity", sender: self)
            }
            if (indexPath.row == 2) {
                self.navigationController?.performSegue(withIdentifier: "segueLocalStorage", sender: self)
            }
        }
        
        // Menu External Site
        if (indexPath.section == 1 && self.menuExternalSite != nil) {
            
            let url : String? = self.menuExternalSite?[indexPath.row].url
            
            if (self.splitViewController?.isCollapsed)! {
                
                let webVC = SwiftWebVC(urlString: url!)
                self.navigationController?.pushViewController(webVC, animated: true)
                self.navigationController?.navigationBar.isHidden = false
                
            } else {
                
                let webVC = SwiftModalWebVC(urlString: url!)
                self.present(webVC, animated: true, completion: nil)
            }
        }
        
        // Menu Settings
        if ((indexPath.section == 1 && self.menuExternalSite == nil) || (indexPath.section == 2 && self.menuExternalSite != nil)) {
            
            if (indexPath.row == 0) {
                self.navigationController?.performSegue(withIdentifier: "segueSettings", sender: self)
            }
        }
    }
}

class CCCellMore: UITableViewCell {
    
    @IBOutlet weak var labelText: UILabel!
    @IBOutlet weak var imageIcon: UIImageView!
}

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
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var labelQuota: UILabel!
    @IBOutlet weak var progressQuota: UIProgressView!

    let itemsMenuLabelText = [["_transfers_","_activity_"], ["_settings_"]]
    let itemsMenuImage = [["transfers","activity"], ["settings"]]
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var menuExternalSite: [TableExternalSites]?
    var tableAccont : TableAccount?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        CCAspect.aspectNavigationControllerBar(self.navigationController?.navigationBar, encrypted: false, online: appDelegate.reachability.isReachable(), hidden: true)
        CCAspect.aspectTabBar(self.tabBarController?.tabBar, hidden: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        self.tableAccont = CCCoreData.getActiveAccount()
        self.menuExternalSite = CCCoreData.getAllTableExternalSites(with:  NSPredicate(format: "(account == '\(appDelegate.activeAccount!)')")) as? [TableExternalSites]
        
        if (self.tableAccont != nil) {
        
            self.progressQuota.progress = Float((self.tableAccont?.quotaRelative)!) / 100
        
            let quota : String = CCUtility.transformedSize(Double((self.tableAccont?.quotaTotal)!))
            let quotaUsed : String = CCUtility.transformedSize(Double((self.tableAccont?.quotaUsed)!))
        
            self.labelQuota.text = String.localizedStringWithFormat(NSLocalizedString("_quota_using_", comment: ""), quotaUsed, quota)
        }
        
        // Avatar
        let avatar : UIImage? = UIImage.init(contentsOfFile: "\(appDelegate.directoryUser!)/avatar.png")
        
        if (avatar != nil) {
            
            //avatar = CCGraphics.scale(avatar, to: CGSize(width: 50, height: 50))
            //let avatarView : APAvatarImageView = APAvatarImageView.init(image: CCGraphics.scale(avatar, to: CGSize(width: 50, height: 50)), borderColor: UIColor.white, borderWidth: 0.5)
            self.imageAvatar.image = avatar
            
        } else {
            
            self.imageAvatar.image = UIImage.init(named: "avatar")
        }
        
        /*
        if (avatar) {
            
            avatar =  [CCGraphics scaleImage:avatar toSize:CGSizeMake(50, 50)];
            APAvatarImageView *avatarImageView = [[APAvatarImageView alloc] initWithImage:avatar borderColor:[UIColor lightGrayColor] borderWidth:0.5];
            
            CGSize imageSize = avatarImageView.bounds.size;
            UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [avatarImageView.layer renderInContext:context];
            avatar = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        */
        
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
        
        var height : CGFloat
        
        if (section == 0) {
            height = 10
        } else {
            height = 30
        }

        return height
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.itemsMenuLabelText[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! CCCellMore
        
        cell.imageIcon?.image = UIImage.init(named: self.itemsMenuImage[indexPath.section][indexPath.row])
        cell.labelText?.text = NSLocalizedString(self.itemsMenuLabelText[indexPath.section][indexPath.row], comment: "")
        
        return cell
    }

    // method to run when table view cell is tapped
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You tapped cell number \(indexPath.row).")
         self.navigationController?.performSegue(withIdentifier: "segueSettings", sender: self)
    }
}

class CCCellMore: UITableViewCell {
    
    @IBOutlet weak var labelText: UILabel!
    @IBOutlet weak var imageIcon: UIImageView!
}

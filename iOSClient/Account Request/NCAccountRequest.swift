//
//  NCAccountRequest.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/02/21.
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

import Foundation
import NCCommunication

class NCAccountRequest: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var progressView: UIProgressView!
    
    public var accounts: [tableAccount] = []
    public let heightCell: CGFloat = 80
    public var enableTimerProgress: Bool = true
    public var enableAddAccount: Bool = false
    public var viewController: UIViewController?
    public var dismissDidEnterBackground: Bool = false

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var timer: Timer?
    private var time: Float = 0
    private let secondsAutoDismiss: Float = 3
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = NSLocalizedString("_accounts_", comment: "")
        
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        progressView.tintColor = NCBrandColor.shared.brandElement
        progressView.trackTintColor = .clear
        progressView.progress = 1
        if enableTimerProgress {
            progressView.isHidden = false
        } else {
            progressView.isHidden = true
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(startTimer), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        
        changeTheming()        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        timer?.invalidate()
    }
    
    // MARK: - NotificationCenter

    @objc func changeTheming() {
        
        view.backgroundColor = NCBrandColor.shared.backgroundView
        tableView.backgroundColor = NCBrandColor.shared.backgroundView
        tableView.reloadData()
    }
    
    @objc func applicationDidEnterBackground() {
        
        if dismissDidEnterBackground {
            dismiss(animated: false)
        }
    }

    // MARK: - Progress
    
    @objc func startTimer() {
        
        if enableTimerProgress {
            time = 0
            timer?.invalidate()
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateProgress), userInfo: nil, repeats: true)
            progressView.isHidden = false
        } else {
            progressView.isHidden = true
        }
    }
    
    @objc func updateProgress() {
        
        time += 0.1
        if time >= secondsAutoDismiss {
            dismiss(animated: true)
        } else {
            progressView.progress = 1 - (time / secondsAutoDismiss)
        }
    }
}

extension NCAccountRequest: UITableViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
        timer?.invalidate()
        progressView.progress = 0
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
//            startTimer()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//        startTimer()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return heightCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.row == accounts.count {
            
            dismiss(animated: true)
            appDelegate.openLogin(viewController: viewController, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            
        } else {
        
            let account = accounts[indexPath.row]
            if account.account != appDelegate.account {
                NCManageDatabase.shared.setAccountActive(account.account)
                dismiss(animated: true) {
                    
                    NCOperationQueue.shared.cancelAllQueue()
                    NCNetworking.shared.cancelAllTask()
                    
                    self.appDelegate.settingAccount(account.account, urlBase: account.urlBase, user: account.user, userId: account.userId, password: CCUtility.getPassword(account.account))
                    
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitializeMain)
                }
            } else {
                dismiss(animated: true)
            }
        }
    }
}

extension NCAccountRequest: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if enableAddAccount {
            return accounts.count + 1
        } else {
            return accounts.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
               
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = NCBrandColor.shared.backgroundView
       
        let avatarImage = cell.viewWithTag(10) as? UIImageView
        let userLabel = cell.viewWithTag(20) as? UILabel
        let urlLabel = cell.viewWithTag(30) as? UILabel
        let activeImage = cell.viewWithTag(40) as? UIImageView

        userLabel?.text = ""
        urlLabel?.text = ""
        
        if indexPath.row == accounts.count {
           
            avatarImage?.image = NCUtility.shared.loadImage(named: "plus").image(color: .systemBlue, size: 25)
            avatarImage?.contentMode = .center
            userLabel?.text = NSLocalizedString("_add_account_", comment: "")
            userLabel?.textColor = .systemBlue
            
        } else {
        
            let account = accounts[indexPath.row]

            avatarImage?.image = NCUtility.shared.loadImage(named: "person.crop.circle")
        
            let fileNamePath = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(account.user, urlBase: account.urlBase)) + "-" + account.user + ".png"
            
            if let image = UIImage(contentsOfFile: fileNamePath) {
                avatarImage?.image = NCUtility.shared.createAvatar(image: image, size: 40)
            }
                    
            if account.alias != "" {
                userLabel?.text = account.alias.uppercased()
            } else {
                userLabel?.text = account.user.uppercased()
                urlLabel?.text = (URL(string: account.urlBase)?.host ?? "")
            }

            if account.active {
                activeImage?.image = NCUtility.shared.loadImage(named: "checkmark").image(color: .systemBlue, size: 30)
            } else {
                activeImage?.image = nil
            }
        }
        
        return cell
    }
}

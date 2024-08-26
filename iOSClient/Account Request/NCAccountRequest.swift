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

import UIKit
import NextcloudKit

public protocol NCAccountRequestDelegate: AnyObject {
    func accountRequestAddAccount()
    func accountRequestChangeAccount(account: String, controller: UIViewController?)
}

class NCAccountRequest: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var progressView: UIProgressView!

    public var accounts: [tableAccount] = []
    public var activeAccount: String?
    public let heightCell: CGFloat = 60
    public var enableTimerProgress: Bool = true
    public var enableAddAccount: Bool = false
    public var dismissDidEnterBackground: Bool = false
    public var controller: UIViewController?
    public weak var delegate: NCAccountRequestDelegate?
    let utility = NCUtility()
    private var timer: Timer?
    private var time: Float = 0
    private let secondsAutoDismiss: Float = 3

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = NSLocalizedString("_account_select_", comment: "")
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none

        view.backgroundColor = .secondarySystemBackground
        tableView.backgroundColor = .secondarySystemBackground

        progressView.trackTintColor = .clear
        progressView.progress = 1
        if enableTimerProgress {
            progressView.isHidden = false
        } else {
            progressView.isHidden = true
        }

        NotificationCenter.default.addObserver(self, selector: #selector(startTimer), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let visibleCells = tableView.visibleCells
        var numAccounts = accounts.count
        if enableAddAccount { numAccounts += 1 }
        if visibleCells.count == numAccounts {
            tableView.isScrollEnabled = false
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        timer?.invalidate()
    }

    // MARK: - NotificationCenter

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
            progressView?.isHidden = false
        } else {
            progressView?.isHidden = true
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

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return heightCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == accounts.count {
            dismiss(animated: true)
            delegate?.accountRequestAddAccount()
        } else {
            let account = accounts[indexPath.row]
            if account.account != activeAccount {
                dismiss(animated: true) {
                    self.delegate?.accountRequestChangeAccount(account: account.account, controller: self.controller)
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
        cell.backgroundColor = tableView.backgroundColor
        let avatarImage = cell.viewWithTag(10) as? UIImageView
        let userLabel = cell.viewWithTag(20) as? UILabel
        let urlLabel = cell.viewWithTag(30) as? UILabel
        let activeImage = cell.viewWithTag(40) as? UIImageView

        userLabel?.text = ""
        urlLabel?.text = ""

        if indexPath.row == accounts.count {

            avatarImage?.image = utility.loadImage(named: "plus", colors: [.systemBlue])
            avatarImage?.contentMode = .center
            userLabel?.text = NSLocalizedString("_add_account_", comment: "")
            userLabel?.textColor = .systemBlue
            userLabel?.font = UIFont.systemFont(ofSize: 15)

        } else {

            let account = accounts[indexPath.row]

            avatarImage?.image = utility.loadUserImage(for: account.user, displayName: account.displayName, urlBase: account.urlBase)

            if account.alias.isEmpty {
                userLabel?.text = account.user.uppercased()
                urlLabel?.text = (URL(string: account.urlBase)?.host ?? "")
            } else {
                userLabel?.text = account.alias.uppercased()
            }

            if account.active {
                activeImage?.image = utility.loadImage(named: "checkmark", colors: [.systemBlue])
            } else {
                activeImage?.image = nil
            }
        }

        return cell
    }
}

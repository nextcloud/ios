//
//  NCTalkAccounts.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 22/11/22.
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

public protocol NCTalkAccountsDelegate: AnyObject {
    func selected(url: String, user: String)
}

// optional func
public extension NCTalkAccountsDelegate {
    func selected(url: String, user: String) {}
}

class NCTalkAccounts: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var progressView: UIProgressView!

    public var accounts: [NKDataAccountFile] = []
    public let heightCell: CGFloat = 60
    public var enableTimerProgress: Bool = true
    public var dismissDidEnterBackground: Bool = true
    public weak var delegate: NCTalkAccountsDelegate?

    private var timer: Timer?
    private var time: Float = 0
    private let secondsAutoDismiss: Float = 3

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = NSLocalizedString("_account_select_to_add_", comment: "")

        closeButton.setImage(NCUtility.shared.loadImage(named: "xmark", color: .label), for: .normal)

        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
        // tableView.separatorStyle = UITableViewCell.SeparatorStyle.none

        view.backgroundColor = .secondarySystemBackground
        tableView.backgroundColor = .secondarySystemBackground

        progressView.trackTintColor = .clear
        progressView.progress = 1
        if enableTimerProgress {
            progressView.isHidden = false
        } else {
            progressView.isHidden = true
        }

        NotificationCenter.default.addObserver(self, selector: #selector(startTimer), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let visibleCells = tableView.visibleCells

        if visibleCells.count == accounts.count {
            tableView.isScrollEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        timer?.invalidate()
    }

    // MARK: - Action

    @IBAction func actionClose(_ sender: UIButton) {
        dismiss(animated: true)
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

extension NCTalkAccounts: UITableViewDelegate {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {

        timer?.invalidate()
        progressView.progress = 0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return heightCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        dismiss(animated: true) {
            let account = self.accounts[indexPath.row]
            self.delegate?.selected(url: account.url, user: account.user)
        }
    }
}

extension NCTalkAccounts: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = tableView.backgroundColor

        let avatarImage = cell.viewWithTag(10) as? UIImageView
        let userLabel = cell.viewWithTag(20) as? UILabel
        let urlLabel = cell.viewWithTag(30) as? UILabel

        userLabel?.text = ""
        urlLabel?.text = ""

        let account = accounts[indexPath.row]

        if let avatarPath = account.avatar, !avatarPath.isEmpty, let avatarImage = avatarImage {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: avatarPath))
                if let image = UIImage(data: data) {
                    avatarImage.image = image
                }
            } catch { print("Error: \(error)") }
        }

        if let alias = account.alias, !alias.isEmpty {
            userLabel?.text = alias.uppercased() + " (\(account.user))"
        } else {
            userLabel?.text = account.user.uppercased()
        }
        urlLabel?.text = (URL(string: account.url)?.host ?? "")

        return cell
    }
}

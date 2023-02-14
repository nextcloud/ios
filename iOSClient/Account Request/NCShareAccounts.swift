//
//  NCShareAccounts.swift
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

public protocol NCShareAccountsDelegate: AnyObject {
    func selected(url: String, user: String)
}

// optional func
public extension NCShareAccountsDelegate {
    func selected(url: String, user: String) {}
}

class NCShareAccounts: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!

    public var accounts: [NKShareAccounts.DataAccounts] = []
    public let heightCell: CGFloat = 60
    public var enableTimerProgress: Bool = true
    public var dismissDidEnterBackground: Bool = true
    public weak var delegate: NCShareAccountsDelegate?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = NSLocalizedString("_account_select_to_add_", comment: "")

        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none

        view.backgroundColor = .secondarySystemBackground
        tableView.backgroundColor = .secondarySystemBackground
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
}

extension NCShareAccounts: UITableViewDelegate {

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

extension NCShareAccounts: UITableViewDataSource {

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

        if let image = account.image {
            avatarImage?.image = image
        }

        if let name = account.name, !name.isEmpty {
            userLabel?.text = name.uppercased() + " (\(account.user))"
        } else {
            userLabel?.text = account.user.uppercased()
        }
        urlLabel?.text = (URL(string: account.url)?.host ?? "")

        return cell
    }
}

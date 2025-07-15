// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later


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

//
//  NCActivity.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/01/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import SwiftRichString
import NextcloudKit

class NCActivity: UIViewController, NCSharePagingContent {

    @IBOutlet weak var tableView: UITableView!

    var commentView: NCActivityCommentView?
    var textField: UITextField? { commentView?.newCommentField }

    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
    var height: CGFloat = 0

    var metadata: tableMetadata?
    var showComments: Bool = false

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    var allItems: [DateCompareable] = []
    var sectionDates: [Date] = []

    var insets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    var didSelectItemEnable: Bool = true
    var objectType: String?

    var isFetchingActivity = false
    var hasActivityToLoad = true {
        didSet { tableView.tableFooterView?.isHidden = hasActivityToLoad }
    }
    var dateAutomaticFetch: Date?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground
        self.title = NSLocalizedString("_activity_", comment: "")

        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.clear
        tableView.contentInset = insets
        tableView.backgroundColor = .systemBackground

        if showComments {
            setupComments()
        }
    }

    func setupComments() {
        // Display Name & Quota
        guard let activeAccount = NCManageDatabase.shared.getActiveAccount(), height > 0 else {
            return
        }

        tableView.register(UINib(nibName: "NCShareCommentsCell", bundle: nil), forCellReuseIdentifier: "cell")
        commentView = Bundle.main.loadNibNamed("NCActivityCommentView", owner: self, options: nil)?.first as? NCActivityCommentView
        commentView?.setup(urlBase: appDelegate, account: activeAccount) { newComment in
            guard let newComment = newComment, !newComment.isEmpty, let metadata = self.metadata else { return }
            NextcloudKit.shared.putComments(fileId: metadata.fileId, message: newComment) { _, error in
                if error == .success {
                    self.commentView?.newCommentField.text?.removeAll()
                    self.loadComments()
                } else {
                    NCContentPresenter.shared.showError(error: error)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDelegate.activeViewController = self

        navigationController?.setFileAppreance()

        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
        initialize()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.tableFooterView = makeTableFooterView()
        tableView.tableHeaderView = commentView
        commentView?.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        commentView?.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        viewContainerConstraint.constant = height
    }

    // MARK: - NotificationCenter

    @objc func initialize() {
        loadDataSource()
        fetchAll(isInitial: true)
        view.setNeedsLayout()
    }

    func makeTableFooterView() -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 100))
        view.backgroundColor = .clear
        view.isHidden = self.hasActivityToLoad

        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor.systemGray
        label.textAlignment = .center
        label.text = NSLocalizedString("_no_activity_footer_", comment: "")
        label.frame = CGRect(x: 0, y: 10, width: tableView.frame.width, height: 60)

        view.addSubview(label)
        return view
    }
}

// MARK: - Table View

extension NCActivity: UITableViewDelegate {

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 60))
        view.backgroundColor = .clear

        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textColor = .label
        label.text = CCUtility.getTitleSectionDate(sectionDates[section])
        label.textAlignment = .center
        label.layer.cornerRadius = 11
        label.layer.masksToBounds = true
        label.layer.backgroundColor = UIColor(red: 152.0/255.0, green: 167.0/255.0, blue: 181.0/255.0, alpha: 0.8).cgColor
        let widthFrame = label.intrinsicContentSize.width + 30
        let xFrame = tableView.bounds.width / 2 - widthFrame / 2
        label.frame = CGRect(x: xFrame, y: 10, width: widthFrame, height: 22)

        view.addSubview(label)
        return view
    }
}

extension NCActivity: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionDates.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let date = sectionDates[section]
        return allItems.filter({ Calendar.current.isDate($0.dateKey, inSameDayAs: date) }).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let date = sectionDates[indexPath.section]
        let sectionItems = allItems
            .filter({ Calendar.current.isDate($0.dateKey, inSameDayAs: date) })
        let cellData = sectionItems[indexPath.row]

        if let activityData = cellData as? tableActivity {
            return makeActivityCell(activityData, for: indexPath)
        } else if let commentData = cellData as? tableComments {
            return makeCommentCell(commentData, for: indexPath)
        } else {
            return UITableViewCell()
        }
    }

    func makeCommentCell(_ comment: tableComments, for indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as? NCShareCommentsCell else {
            return UITableViewCell()
        }

        cell.tableComments = comment
        cell.delegate = self
        cell.sizeToFit()

        // Image
        let fileName = appDelegate.userBaseUrl + "-" + comment.actorId + ".png"
        NCOperationQueue.shared.downloadAvatar(user: comment.actorId, dispalyName: comment.actorDisplayName, fileName: fileName, cell: cell, view: tableView, cellImageView: cell.fileAvatarImageView)
        // Username
        cell.labelUser.text = comment.actorDisplayName
        cell.labelUser.textColor = .label
        // Date
        cell.labelDate.text = CCUtility.dateDiff(comment.creationDateTime as Date)
        cell.labelDate.textColor = .systemGray4
        // Message
        cell.labelMessage.text = comment.message
        cell.labelMessage.textColor = .label
        // Button Menu
        if comment.actorId == appDelegate.userId {
            cell.buttonMenu.isHidden = false
        } else {
            cell.buttonMenu.isHidden = true
        }

        return cell
    }

    func makeActivityCell(_ activity: tableActivity, for indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for: indexPath) as? NCActivityTableViewCell else {
            return UITableViewCell()
        }

        var orderKeysId: [String] = []

        cell.idActivity = activity.idActivity

        cell.avatar.image = nil
        cell.avatar.isHidden = true
        cell.subjectTrailingConstraint.constant = 10
        cell.didSelectItemEnable = self.didSelectItemEnable
        cell.subject.textColor = .label
        cell.viewController = self

        // icon
        if activity.icon.count > 0 {

            let fileNameIcon = (activity.icon as NSString).lastPathComponent
            let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + fileNameIcon

            if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                    cell.icon.image = image
                }
            } else {
                NextcloudKit.shared.downloadContent(serverUrl: activity.icon) { _, data, error in
                    if error == .success {
                        do {
                            try data!.write(to: NSURL(fileURLWithPath: fileNameLocalPath) as URL, options: .atomic)
                            self.tableView.reloadData()
                        } catch { return }
                    }
                }
            }
        }

        // avatar
        if activity.user.count > 0 && activity.user != appDelegate.userId {

            cell.subjectTrailingConstraint.constant = 50
            cell.avatar.isHidden = false
            cell.fileUser = activity.user

            let fileName = appDelegate.userBaseUrl + "-" + activity.user + ".png"

            NCOperationQueue.shared.downloadAvatar(user: activity.user, dispalyName: nil, fileName: fileName, cell: cell, view: tableView, cellImageView: cell.fileAvatarImageView)
        }

        // subject
        cell.subject.text = activity.subject
        if activity.subjectRich.count > 0 {

            var subject = activity.subjectRich
            var keys: [String] = []

            if let regex = try? NSRegularExpression(pattern: "\\{[a-z0-9]+\\}", options: .caseInsensitive) {
                let string = subject as NSString
                keys = regex.matches(in: subject, options: [], range: NSRange(location: 0, length: string.length)).map {
                    string.substring(with: $0.range).replacingOccurrences(of: "[\\{\\}]", with: "", options: .regularExpression)
                }
            }

            for key in keys {
                if let result = NCManageDatabase.shared.getActivitySubjectRich(account: appDelegate.account, idActivity: activity.idActivity, key: key) {
                    orderKeysId.append(result.id)
                    subject = subject.replacingOccurrences(of: "{\(key)}", with: "<bold>" + result.name + "</bold>")
                }
            }

            let normal = Style {
                $0.font = UIFont.systemFont(ofSize: cell.subject.font.pointSize)
                $0.lineSpacing = 1.5
            }
            let bold = Style { $0.font = UIFont.systemFont(ofSize: cell.subject.font.pointSize, weight: .bold) }
            let date = Style { $0.font = UIFont.systemFont(ofSize: cell.subject.font.pointSize - 3)
                $0.color = UIColor.lightGray
            }

            subject += "\n" + "<date>" + CCUtility.dateDiff(activity.date as Date) + "</date>"
            cell.subject.attributedText = subject.set(style: StyleGroup(base: normal, ["bold": bold, "date": date]))
        }

        // CollectionView
        cell.activityPreviews = NCManageDatabase.shared.getActivityPreview(account: activity.account, idActivity: activity.idActivity, orderKeysId: orderKeysId)
        if cell.activityPreviews.count == 0 {
            cell.collectionViewHeightConstraint.constant = 0
        } else {
            cell.collectionViewHeightConstraint.constant = 60
        }
        cell.collectionView.reloadData()

        return cell
    }
}

// MARK: - ScrollView

extension NCActivity: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard
            scrollView.contentOffset.y > 50,
            scrollView.contentSize.height - scrollView.frame.height - scrollView.contentOffset.y < -50
        else { return }
        fetchAll(isInitial: false)
    }
}

// MARK: - NC API & Algorithm

extension NCActivity {

    func fetchAll(isInitial: Bool) {
        guard !isFetchingActivity else { return }
        self.isFetchingActivity = true

        var bottom: CGFloat = 0
        if let mainTabBar = self.tabBarController?.tabBar as? NCMainTabBar {
            bottom = -mainTabBar.getHight()
        }
        NCActivityIndicator.shared.start(backgroundView: self.view, bottom: bottom-5, style: .medium)

        let dispatchGroup = DispatchGroup()
        loadComments(disptachGroup: dispatchGroup)

        if !isInitial, let activity = allItems.compactMap({ $0 as? tableActivity }).last {
            loadActivity(idActivity: activity.idActivity, disptachGroup: dispatchGroup)
        } else {
            checkRecentActivity(disptachGroup: dispatchGroup)
        }

        dispatchGroup.notify(queue: .main) {
            self.loadDataSource()
            NCActivityIndicator.shared.stop()

            // otherwise is triggered again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isFetchingActivity = false
            }
        }
    }

    func loadDataSource() {

        var newItems = [DateCompareable]()
        if showComments, let metadata = metadata, let account = NCManageDatabase.shared.getActiveAccount() {
            let comments = NCManageDatabase.shared.getComments(account: account.account, objectId: metadata.fileId)
            newItems += comments
        }

        let activities = NCManageDatabase.shared.getActivity(
            predicate: NSPredicate(format: "account == %@", appDelegate.account),
            filterFileId: metadata?.fileId)
        newItems += activities.filter

        self.allItems = newItems.sorted(by: { $0.dateKey > $1.dateKey })
        self.sectionDates = self.allItems.reduce(into: Set<Date>()) { partialResult, next in
            let newDay = Calendar.current.startOfDay(for: next.dateKey)
            partialResult.insert(newDay)
        }.sorted(by: >)
        self.tableView.reloadData()
    }

    func loadComments(disptachGroup: DispatchGroup? = nil) {
        guard showComments, let metadata = metadata else { return }
        disptachGroup?.enter()

        NextcloudKit.shared.getComments(fileId: metadata.fileId) { account, comments, data, error in
            if error == .success, let comments = comments {
                NCManageDatabase.shared.addComments(comments, account: metadata.account, objectId: metadata.fileId)
            } else if error.errorCode != NCGlobal.shared.errorResourceNotFound {
                NCContentPresenter.shared.showError(error: error)
            }

            if let disptachGroup = disptachGroup {
                disptachGroup.leave()
            } else {
                self.loadDataSource()
            }
        }
    }

    /// Check if most recent activivities are loaded, if not trigger reload
    func checkRecentActivity(disptachGroup: DispatchGroup) {
        guard let result = NCManageDatabase.shared.getLatestActivityId(account: appDelegate.account), metadata == nil, hasActivityToLoad else {
            return self.loadActivity(idActivity: 0, disptachGroup: disptachGroup)
        }
        let resultActivityId = max(result.activityFirstKnown, result.activityLastGiven)

        disptachGroup.enter()

        NextcloudKit.shared.getActivity(
            since: 0,
            limit: 1,
            objectId: nil,
            objectType: objectType,
            previews: true) { account, _, activityFirstKnown, activityLastGiven, data, error in
                defer { disptachGroup.leave() }

                let largestActivityId = max(activityFirstKnown, activityLastGiven)
                guard error == .success,
                      account == self.appDelegate.account,
                      largestActivityId > resultActivityId
                else {
                    self.hasActivityToLoad = error.errorCode == NCGlobal.shared.errorNotModified ? false : self.hasActivityToLoad
                    return
                }

                self.loadActivity(idActivity: 0, limit: largestActivityId - resultActivityId, disptachGroup: disptachGroup)
            }
    }

    func loadActivity(idActivity: Int, limit: Int = 200, disptachGroup: DispatchGroup) {
        guard hasActivityToLoad else { return }

        var resultActivityId = 0
        disptachGroup.enter()

        NextcloudKit.shared.getActivity(
            since: idActivity,
            limit: min(limit, 200),
            objectId: metadata?.fileId,
            objectType: objectType,
            previews: true) { account, activities, activityFirstKnown, activityLastGiven, data, error in
                defer { disptachGroup.leave() }
                guard error == .success,
                      account == self.appDelegate.account,
                      !activities.isEmpty
                else {
                    self.hasActivityToLoad = error.errorCode == NCGlobal.shared.errorNotModified ? false : self.hasActivityToLoad
                    return
                }
                NCManageDatabase.shared.addActivity(activities, account: account)

                // update most recently loaded activity only when all activities are loaded (not filtered)
                let largestActivityId = max(activityFirstKnown, activityLastGiven)
                if let result = NCManageDatabase.shared.getLatestActivityId(account: self.appDelegate.account) {
                    resultActivityId = max(result.activityFirstKnown, result.activityLastGiven)
                }
                if self.metadata == nil, largestActivityId > resultActivityId {
                    NCManageDatabase.shared.updateLatestActivityId(activityFirstKnown: activityFirstKnown, activityLastGiven: activityLastGiven, account: account)
                }
            }
    }
}

extension NCActivity: NCShareCommentsCellDelegate {
    func showProfile(with tableComment: tableComments?, sender: Any) {
        guard let tableComment = tableComment else {
            return
        }
        self.showProfileMenu(userId: tableComment.actorId)
    }

    func tapMenu(with tableComments: tableComments?, sender: Any) {
        toggleMenu(with: tableComments)
    }

    func toggleMenu(with tableComments: tableComments?) {
        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_edit_comment_", comment: ""),
                icon: UIImage(named: "pencil")!.image(color: UIColor.systemGray, size: 50),
                action: { _ in
                    guard let metadata = self.metadata, let tableComments = tableComments else { return }

                    let alert = UIAlertController(title: NSLocalizedString("_edit_comment_", comment: ""), message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))

                    alert.addTextField(configurationHandler: { textField in
                        textField.placeholder = NSLocalizedString("_new_comment_", comment: "")
                    })

                    alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                        guard let message = alert.textFields?.first?.text, message != "" else { return }

                        NextcloudKit.shared.updateComments(fileId: metadata.fileId, messageId: tableComments.messageId, message: message) { _, error in
                            if error == .success {
                                self.loadComments()
                            } else {
                                NCContentPresenter.shared.showError(error: error)
                            }
                        }
                    }))

                    self.present(alert, animated: true)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_comment_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "trash"),
                action: { _ in
                    guard let metadata = self.metadata, let tableComments = tableComments else { return }

                    NextcloudKit.shared.deleteComments(fileId: metadata.fileId, messageId: tableComments.messageId) { _, error in
                        if error == .success {
                            self.loadComments()
                        } else {
                            NCContentPresenter.shared.showError(error: error)
                        }
                    }
                }
            )
        )

        presentMenu(with: actions)
    }
}

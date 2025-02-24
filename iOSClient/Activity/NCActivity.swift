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
import SVGKit

class NCActivity: UIViewController, NCSharePagingContent {
    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableView: UITableView!

    var commentView: NCActivityCommentView?
    var textField: UIView? { commentView?.newCommentField }
    var height: CGFloat = 0
    var metadata: tableMetadata?
    var showComments: Bool = false

    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    var allItems: [DateCompareable] = []
    var sectionDates: [Date] = []
    var dataSourceTask: URLSessionTask?

    var insets = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
    var didSelectItemEnable: Bool = true
    var objectType: String?
    var account: String = ""

    var isFetchingActivity = false
    var hasActivityToLoad = true {
        didSet { tableView.tableFooterView?.isHidden = hasActivityToLoad }
    }
    var dateAutomaticFetch: Date?

    var session: NCSession.Session {
        if account.isEmpty {
            NCSession.shared.getSession(controller: tabBarController)
        } else {
            NCSession.shared.getSession(account: account)
        }
    }

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
        guard let metadata else { return }
        tableView.register(UINib(nibName: "NCShareCommentsCell", bundle: nil), forCellReuseIdentifier: "cell")
        commentView = Bundle.main.loadNibNamed("NCActivityCommentView", owner: self, options: nil)?.first as? NCActivityCommentView
        commentView?.setup(account: metadata.account) { newComment in
            guard let newComment = newComment, !newComment.isEmpty, let metadata = self.metadata else { return }
            NextcloudKit.shared.putComments(fileId: metadata.fileId, message: newComment, account: metadata.account) { _, _, error in
                if error == .success {
                    self.commentView?.newCommentField.text?.removeAll()
                    self.loadComments()
                } else {
                    NCContentPresenter().showError(error: error)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarAppearance()
        fetchAll(isInitial: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Cancel Queue & Retrieves Properties
        NCNetworking.shared.downloadThumbnailActivityQueue.cancelAll()
        dataSourceTask?.cancel()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.tableFooterView = makeTableFooterView()
        tableView.tableHeaderView = commentView
        commentView?.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        commentView?.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        viewContainerConstraint.constant = height - 10
    }

    func makeTableFooterView() -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 100))
        view.backgroundColor = .clear
        view.isHidden = self.hasActivityToLoad

        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = NCBrandColor.shared.textColor2
        label.textAlignment = .center
        label.text = NSLocalizedString("_no_activity_footer_", comment: "")
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: view.topAnchor, constant: 20).isActive = true
        label.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        label.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        return view
    }
}

// MARK: - Table View

extension NCActivity: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 50))
        view.backgroundColor = .clear

        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textColor = NCBrandColor.shared.textColor
        label.text = utility.getTitleFromDate(sectionDates[section])
        label.textAlignment = .center

        let blur = UIBlurEffect(style: .systemMaterial)
        let blurredEffectView = UIVisualEffectView(effect: blur)
        blurredEffectView.layer.cornerRadius = 11
        blurredEffectView.layer.masksToBounds = true

        view.addSubview(blurredEffectView)
        view.addSubview(label)

        blurredEffectView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            blurredEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            blurredEffectView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blurredEffectView.widthAnchor.constraint(equalToConstant: label.intrinsicContentSize.width + 30),
            blurredEffectView.heightAnchor.constraint(equalToConstant: 22),
            label.topAnchor.constraint(equalTo: view.topAnchor),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: blurredEffectView.centerYAnchor)
        ])

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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as? NCShareCommentsCell,
              let metadata else {
            return UITableViewCell()
        }

        cell.indexPath = indexPath
        cell.tableComments = comment
        cell.delegate = self

        // Avatar
        let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: comment.actorId)
        let results = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName)

        if results.image == nil {
            cell.fileAvatarImageView?.image = utility.loadUserImage(for: comment.actorId, displayName: comment.actorDisplayName, urlBase: NCSession.shared.getSession(account: account).urlBase)
        } else {
            cell.fileAvatarImageView?.image = results.image
        }

        if let tableAvatar = results.tableAvatar,
           !tableAvatar.loaded,
           NCNetworking.shared.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
            NCNetworking.shared.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: comment.actorId, fileName: fileName, account: account, view: tableView))
        }

        // Username
        cell.labelUser.text = comment.actorDisplayName
        cell.labelUser.textColor = NCBrandColor.shared.textColor
        // Date
        cell.labelDate.text = utility.getRelativeDateTitle(comment.creationDateTime as Date)
        cell.labelDate.textColor = .lightGray
        // Message
        cell.labelMessage.text = comment.message
        cell.labelMessage.textColor = NCBrandColor.shared.textColor
        // Button Menu
        if comment.actorId == metadata.userId {
            cell.buttonMenu.isHidden = false
        } else {
            cell.buttonMenu.isHidden = true
        }

        cell.sizeToFit()

        return cell
    }

    func makeActivityCell(_ activity: tableActivity, for indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for: indexPath) as? NCActivityTableViewCell else {
            return UITableViewCell()
        }
        var orderKeysId: [String] = []

        cell.idActivity = activity.idActivity
        cell.account = activity.account
        cell.indexPath = indexPath
        cell.avatar.image = nil
        cell.avatar.isHidden = true
        cell.didSelectItemEnable = self.didSelectItemEnable
        cell.subject.textColor = NCBrandColor.shared.textColor
        cell.viewController = self

        // icon
        if !activity.icon.isEmpty {
            activity.icon = activity.icon.replacingOccurrences(of: ".png", with: ".svg")
            let fileNameIcon = (activity.icon as NSString).lastPathComponent
            let fileNameLocalPath = utilityFileSystem.directoryUserData + "/" + fileNameIcon

            if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                let image = fileNameIcon.contains(".svg") ? SVGKImage(contentsOfFile: fileNameLocalPath)?.uiImage : UIImage(contentsOfFile: fileNameLocalPath)

                if let image {
                    cell.icon.image = image.withTintColor(NCBrandColor.shared.textColor, renderingMode: .alwaysOriginal)
                }
            } else {
                NextcloudKit.shared.downloadContent(serverUrl: activity.icon, account: activity.account) { _, responseData, error in
                    if error == .success, let data = responseData?.data {
                        do {
                            try data.write(to: NSURL(fileURLWithPath: fileNameLocalPath) as URL, options: .atomic)
                            self.tableView.reloadData()
                        } catch { return }
                    }
                }
            }
        }

        // avatar
        if !activity.user.isEmpty && activity.user != session.userId {
            cell.avatar.isHidden = false
            cell.fileUser = activity.user
            cell.subjectLeadingConstraint.constant = 15

            let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: activity.user)
            let results = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName)

            if results.image == nil {
                cell.fileAvatarImageView?.image = utility.loadUserImage(for: activity.user, displayName: nil, urlBase: session.urlBase)
            } else {
                cell.fileAvatarImageView?.image = results.image
            }

            if !(results.tableAvatar?.loaded ?? false),
               NCNetworking.shared.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
                NCNetworking.shared.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: activity.user, fileName: fileName, account: session.account, view: tableView))
            }
        } else {
            cell.subjectLeadingConstraint.constant = -30
        }

        // subject
        cell.subject.text = activity.subject
        if !activity.subjectRich.isEmpty {
            var subject = activity.subjectRich
            var keys: [String] = []

            if let regex = try? NSRegularExpression(pattern: "\\{[a-z0-9]+\\}", options: .caseInsensitive) {
                let string = subject as NSString
                keys = regex.matches(in: subject, options: [], range: NSRange(location: 0, length: string.length)).map {
                    string.substring(with: $0.range).replacingOccurrences(of: "[\\{\\}]", with: "", options: .regularExpression)
                }
            }

            for key in keys {
                if let result = database.getActivitySubjectRich(account: session.account, idActivity: activity.idActivity, key: key) {
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

            subject += "\n" + "<date>" + utility.getRelativeDateTitle(activity.date as Date) + "</date>"
            cell.subject.attributedText = subject.set(style: StyleGroup(base: normal, ["bold": bold, "date": date]))
        }

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
           bottom = -mainTabBar.getHeight()
        }
        NCActivityIndicator.shared.start(backgroundView: self.view, bottom: bottom - 35, style: .medium)

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

        if showComments, let metadata {
            let comments = database.getComments(account: metadata.account, objectId: metadata.fileId)
            newItems += comments
        }

        let activities = database.getActivity(
            predicate: NSPredicate(format: "account == %@", session.account),
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

        NextcloudKit.shared.getComments(fileId: metadata.fileId, account: metadata.account) { _, comments, _, error in
            if error == .success, let comments = comments {
                self.database.addComments(comments, account: metadata.account, objectId: metadata.fileId)
            } else if error.errorCode != NCGlobal.shared.errorResourceNotFound {
                NCContentPresenter().showError(error: error)
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
        guard let result = database.getLatestActivityId(account: session.account), metadata == nil, hasActivityToLoad else {
            return self.loadActivity(idActivity: 0, disptachGroup: disptachGroup)
        }
        let resultActivityId = max(result.activityFirstKnown, result.activityLastGiven)

        disptachGroup.enter()

        NextcloudKit.shared.getActivity(
            since: 0,
            limit: 1,
            objectId: nil,
            objectType: objectType,
            previews: true,
            account: session.account) { task in
                self.dataSourceTask = task
            } completion: { account, _, activityFirstKnown, activityLastGiven, _, error in
                defer { disptachGroup.leave() }

                let largestActivityId = max(activityFirstKnown, activityLastGiven)
                guard error == .success,
                      account == self.session.account,
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
            previews: true,
            account: session.account) { task in
                self.dataSourceTask = task
            } completion: { account, activities, activityFirstKnown, activityLastGiven, _, error in
                defer { disptachGroup.leave() }
                guard error == .success,
                      account == self.session.account,
                      !activities.isEmpty
                else {
                    self.hasActivityToLoad = error.errorCode == NCGlobal.shared.errorNotModified ? false : self.hasActivityToLoad
                    return
                }
                self.database.addActivity(activities, account: account)

                // update most recently loaded activity only when all activities are loaded (not filtered)
                let largestActivityId = max(activityFirstKnown, activityLastGiven)
                if let result = self.database.getLatestActivityId(account: self.session.account) {
                    resultActivityId = max(result.activityFirstKnown, result.activityLastGiven)
                }
                if self.metadata == nil, largestActivityId > resultActivityId {
                    self.database.updateLatestActivityId(activityFirstKnown: activityFirstKnown, activityLastGiven: activityLastGiven, account: account)
                }
            }
    }
}

extension NCActivity: NCShareCommentsCellDelegate {
    func showProfile(with tableComment: tableComments?, sender: Any) {
        guard let tableComment = tableComment else {
            return
        }
        self.showProfileMenu(userId: tableComment.actorId, session: session)
    }

    func tapMenu(with tableComments: tableComments?, sender: Any) {
        toggleMenu(with: tableComments)
    }

    func toggleMenu(with tableComments: tableComments?) {
        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_edit_comment_", comment: ""),
                icon: utility.loadImage(named: "pencil", colors: [NCBrandColor.shared.iconImageColor]),
                action: { _ in
                    guard let metadata = self.metadata, let tableComments = tableComments else { return }

                    let alert = UIAlertController(title: NSLocalizedString("_edit_comment_", comment: ""), message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))

                    alert.addTextField(configurationHandler: { textField in
                        textField.placeholder = NSLocalizedString("_new_comment_", comment: "")
                    })

                    alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                        guard let message = alert.textFields?.first?.text, !message.isEmpty else { return }

                        NextcloudKit.shared.updateComments(fileId: metadata.fileId, messageId: tableComments.messageId, message: message, account: metadata.account) { _, _, error in
                            if error == .success {
                                self.loadComments()
                            } else {
                                NCContentPresenter().showError(error: error)
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
                destructive: true,
                icon: utility.loadImage(named: "trash", colors: [.red]),
                action: { _ in
                    guard let metadata = self.metadata, let tableComments = tableComments else { return }

                    NextcloudKit.shared.deleteComments(fileId: metadata.fileId, messageId: tableComments.messageId, account: metadata.account) { _, _, error in
                        if error == .success {
                            self.loadComments()
                        } else {
                            NCContentPresenter().showError(error: error)
                        }
                    }
                }
            )
        )

        presentMenu(with: actions)
    }
}

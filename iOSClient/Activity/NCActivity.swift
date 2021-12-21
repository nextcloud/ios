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
import NCCommunication

class NCActivity: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var commentView: UIView!
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelUser: UILabel!
    @IBOutlet weak var newCommentField: UITextField!

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
    
    var canFetchActivity = true
    var dateAutomaticFetch : Date?
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = NCBrandColor.shared.systemBackground
        self.title = NSLocalizedString("_activity_", comment: "")

        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.clear
        tableView.tableFooterView = UIView()
        tableView.contentInset = insets
        tableView.backgroundColor = NCBrandColor.shared.systemBackground
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        
        changeTheming()

        if showComments {
            setupComments()
        } else {
            commentView.isHidden = true
        }
    }
    
    func setupComments() {
        tableView.register(UINib.init(nibName: "NCShareCommentsCell", bundle: nil), forCellReuseIdentifier: "cell")


        newCommentField.placeholder = NSLocalizedString("_new_comment_", comment: "")
        viewContainerConstraint.constant = height

        // Display Name & Quota
        guard let activeAccount = NCManageDatabase.shared.getActiveAccount(), height > 0 else {
            commentView.isHidden = true
            return
        }
        
        let fileName = String(CCUtility.getUserUrlBase(appDelegate.user, urlBase: appDelegate.urlBase)) + "-" + appDelegate.user + ".png"
        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
        if let image = UIImage(contentsOfFile: fileNameLocalPath) {
            imageItem.image = image
        } else {
            imageItem.image = UIImage(named: "avatar")
        }
        
        if activeAccount.displayName.isEmpty {
            labelUser.text = activeAccount.user
        } else {
            labelUser.text = activeAccount.displayName
        }
        labelUser.textColor = NCBrandColor.shared.label
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        appDelegate.activeViewController = self

        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
        
        initialize()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
    }
    
    // MARK: - NotificationCenter

    @objc func initialize() {
        loadDataSource()
        fetchAll(isInitial: true)
    }
    
    @objc func changeTheming() {
        tableView.reloadData()
    }
    
    @IBAction func newCommentFieldDidEndOnExit(textField: UITextField) {
        guard
            let message = textField.text,
            !message.isEmpty,
            let metadata = self.metadata
        else { return }

        NCCommunication.shared.putComments(fileId: metadata.fileId, message: message) { (account, errorCode, errorDescription) in
            if errorCode == 0 {
                self.newCommentField.text = ""
                self.loadComments()
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
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
        label.textColor = NCBrandColor.shared.label
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
        let fileName = String(CCUtility.getUserUrlBase(appDelegate.user, urlBase: appDelegate.urlBase)) + "-" + comment.actorId + ".png"
        NCOperationQueue.shared.downloadAvatar(user: comment.actorId, fileName: fileName, placeholder: UIImage(named: "avatar"), cell: cell, view: tableView)
        // Username
        cell.labelUser.text = comment.actorDisplayName
        cell.labelUser.textColor = NCBrandColor.shared.label
        // Date
        cell.labelDate.text = CCUtility.dateDiff(comment.creationDateTime as Date)
        cell.labelDate.textColor = NCBrandColor.shared.systemGray4
        // Message
        cell.labelMessage.text = comment.message
        cell.labelMessage.textColor = NCBrandColor.shared.label
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
        cell.account = activity.account
        cell.avatar.image = nil
        cell.avatar.isHidden = true
        cell.subjectTrailingConstraint.constant = 10
        cell.didSelectItemEnable = self.didSelectItemEnable
        cell.subject.textColor = NCBrandColor.shared.label
        cell.viewController = self
        
        // icon
        if activity.icon.count > 0 {
            
            let fileNameIcon = (activity.icon as NSString).lastPathComponent
            let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + fileNameIcon
            
            if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                if let image = UIImage(contentsOfFile: fileNameLocalPath) { cell.icon.image = image }
            } else {
                NCCommunication.shared.downloadContent(serverUrl: activity.icon) { (account, data, errorCode, errorMessage) in
                    if errorCode == 0 {
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
            
            let fileName = String(CCUtility.getUserUrlBase(appDelegate.user, urlBase: appDelegate.urlBase)) + "-" + activity.user + ".png"
            
            NCOperationQueue.shared.downloadAvatar(user: activity.user, fileName: fileName, placeholder: UIImage(named: "avatar"), cell: cell, view: tableView)
        }
        
        // subject
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
            
            subject = subject + "\n" + "<date>" + CCUtility.dateDiff(activity.date as Date) + "</date>"
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
        guard canFetchActivity else { return }
        self.canFetchActivity = false

        let height = self.tabBarController?.tabBar.frame.size.height ?? 0
        NCUtility.shared.startActivityIndicator(backgroundView: self.view, blurEffect: false, bottom: height + 50, style: .gray)

        let dispatchGroup = DispatchGroup()
        loadComments(disptachGroup: dispatchGroup)
        if !isInitial, let activity = allItems.compactMap({ $0 as? tableActivity }).last {
            loadActivity(idActivity: activity.idActivity, disptachGroup: dispatchGroup)
        } else {
            checkRecentActivity(disptachGroup: dispatchGroup)
        }

        dispatchGroup.notify(queue: .main) {
            self.loadDataSource()
            NCUtility.shared.stopActivityIndicator()

            // otherwise is triggered again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.canFetchActivity = true
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

        NCCommunication.shared.getComments(fileId: metadata.fileId) { (account, comments, errorCode, errorDescription) in
            if errorCode == 0, let comments = comments {
                NCManageDatabase.shared.addComments(comments, account: metadata.account, objectId: metadata.fileId)
            } else if errorCode != NCGlobal.shared.errorResourceNotFound {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
        let recentActivityId = NCManageDatabase.shared.getLatestActivityId(account: appDelegate.account)

        guard recentActivityId > 0, metadata == nil else {
            return self.loadActivity(idActivity: 0, disptachGroup: disptachGroup)
        }

        disptachGroup.enter()

        NCCommunication.shared.getActivity(
            since: 0,
            limit: 1,
            objectId: nil,
            objectType: objectType,
            previews: true) { (account, activities, errorCode, errorDescription) in
                defer { disptachGroup.leave() }

                guard errorCode == 0,
                      account == self.appDelegate.account,
                      let activity = activities.first,
                      activity.idActivity > recentActivityId
                else { return }

                self.loadActivity(idActivity: 0, limit: activity.idActivity - recentActivityId, disptachGroup: disptachGroup)
            }
    }

    func loadActivity(idActivity: Int, limit: Int = 200, disptachGroup: DispatchGroup) {
        disptachGroup.enter()

        NCCommunication.shared.getActivity(
            since: idActivity,
            limit: min(limit, 200),
            objectId: metadata?.fileId,
            objectType: objectType,
            previews: true) { (account, activities, errorCode, errorDescription) in
                defer { disptachGroup.leave() }
                guard errorCode == 0,
                      account == self.appDelegate.account,
                      !activities.isEmpty
                else { return }
                NCManageDatabase.shared.addActivity(activities, account: account)

                // update most recently loaded activity only when all activities are loaded (not filtered)
                if self.metadata == nil {
                    NCManageDatabase.shared.updateLatestActivityId(activities, account: account)
                }
            }
    }
}

extension NCActivity: NCShareCommentsCellDelegate {
    func tapMenu(with tableComments: tableComments?, sender: Any) {
        toggleMenu(with: tableComments)
    }

    func toggleMenu(with tableComments: tableComments?) {

        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_edit_comment_", comment: ""),
                icon: UIImage(named: "edit")!.image(color: NCBrandColor.shared.gray, size: 50),
                action: { menuAction in
                    guard let metadata = self.metadata, let tableComments = tableComments else { return }
                    
                    let alert = UIAlertController(title: NSLocalizedString("_edit_comment_", comment: ""), message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))
                    
                    alert.addTextField(configurationHandler: { textField in
                        textField.placeholder = NSLocalizedString("_new_comment_", comment: "")
                    })
                    
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in
                        guard let message = alert.textFields?.first?.text, message != "" else { return }

                        NCCommunication.shared.updateComments(fileId: metadata.fileId, messageId: tableComments.messageId, message: message) { (account, errorCode, errorDescription) in
                            if errorCode == 0 {
                                self.loadComments()
                            } else {
                                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
                action: { menuAction in
                    guard let metadata = self.metadata, let tableComments = tableComments else { return }

                    NCCommunication.shared.deleteComments(fileId: metadata.fileId, messageId: tableComments.messageId) { (account, errorCode, errorDescription) in
                        if errorCode == 0 {
                            self.loadComments()
                        } else {
                            NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            )
        )

        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)
        self.present(menuPanelController, animated: true, completion: nil)
    }
}


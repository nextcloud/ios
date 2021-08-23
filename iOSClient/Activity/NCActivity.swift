//
//  NCActivity.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/01/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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
import SwiftRichString
import NCCommunication

class NCActivity: UIViewController, NCEmptyDataSetDelegate {
    
    @IBOutlet weak var tableView: UITableView!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    var emptyDataSet: NCEmptyDataSet?
    var allActivities: [tableActivity] = []
    var filterActivities: [tableActivity] = []

    var sectionDate: [Date] = []
    var insets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    var didSelectItemEnable: Bool = true
    var filterFileId: String?
    var objectType: String?
    
    var canFetchActivity = true
    var dateAutomaticFetch : Date?
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = NCBrandColor.shared.systemBackground
        self.title = NSLocalizedString("_activity_", comment: "")

        // Empty
        emptyDataSet = NCEmptyDataSet.init(view: tableView, offset: 0, delegate: self)
        
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.clear
        tableView.tableFooterView = UIView()
        tableView.contentInset = insets
        tableView.backgroundColor = NCBrandColor.shared.systemBackground
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        appDelegate.activeViewController = self
        
        //
        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        initialize()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
    }
    
    // MARK: - NotificationCenter

    @objc func initialize() {
        loadDataSource()
        loadActivity(idActivity: 0)
    }
    
    @objc func changeTheming() {
        tableView.reloadData()
    }
    
    // MARK: - Empty
    
    func emptyDataSetView(_ view: NCEmptyView) {
        
        view.emptyImage.image = UIImage.init(named: "bolt")?.image(color: .gray, size: UIScreen.main.bounds.width)
        view.emptyTitle.text = NSLocalizedString("_no_activity_", comment: "")
        view.emptyDescription.text = ""
    }
}

class activityTableViewCell: UITableViewCell, NCCellProtocol {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var subjectTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!

    private var user: String = ""

    var idActivity: Int = 0
    var account: String = ""
    var activityPreviews: [tableActivityPreview] = []
    var didSelectItemEnable: Bool = true
    var viewController: UIViewController? = nil
    
    var fileAvatarImageView: UIImageView? {
        get {
            return avatar
        }
    }
    var fileObjectId: String? {
        get {
            return nil
        }
    }
    var filePreviewImageView: UIImageView? {
        get {
            return nil
        }
    }
    var fileUser: String? {
        get {
            return user
        }
        set {
            user = newValue ?? ""
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        collectionView.delegate = self
        collectionView.dataSource = self
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
        label.text = CCUtility.getTitleSectionDate(sectionDate[section])
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
        return sectionDate.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberItems = getTableActivitiesFromSection(section).count
        emptyDataSet?.numberOfItemsInSection(numberItems, section: section)
        return numberItems
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for: indexPath) as? activityTableViewCell {
            
            let results = getTableActivitiesFromSection(indexPath.section)
            let activity = results[indexPath.row]
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
                    DispatchQueue.global().async {
                        NCCommunication.shared.downloadContent(serverUrl: activity.icon) { (account, data, errorCode, errorMessage) in
                            if errorCode == 0 {
                                do {
                                    try data!.write(to: NSURL(fileURLWithPath: fileNameLocalPath) as URL, options: .atomic)
                                    if let image = UIImage(contentsOfFile: fileNameLocalPath) { cell.icon.image = image }
                                } catch { return }
                            }
                        }
                    }
                }
            }
            
            // avatar
            if activity.user.count > 0 && activity.user != appDelegate.userId {
                
                cell.subjectTrailingConstraint.constant = 50
                cell.avatar.isHidden = false
                cell.fileUser = activity.user
                
                let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase)) + "-" + activity.user + ".png"
                NCOperationQueue.shared.downloadAvatar(user: activity.user, fileNameLocalPath: fileNameLocalPath, placeholder: UIImage(named: "avatar"), cell: cell, view: tableView)
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
        
        return UITableViewCell()
    }
}

/*
extension NCActivity: UITableViewDataSourcePrefetching {
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
        let section = indexPaths.last?.section ?? 0
        let row = indexPaths.last?.row ?? 0
        
        let lastSection = self.sectionDate.count - 1
        let lastRow = getTableActivitiesFromSection(section).count - 1
        
        if section == lastSection && row > lastRow - 1 {
            //loadActivity(idActivity: allActivities.last!.idActivity)
        }
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        //print("cancelPrefetchingForRowsAt \(indexPaths)")
    }
}
*/

// MARK: - ScrollView

extension NCActivity: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.height < 100 {
            if let activities = allActivities.last {
                loadActivity(idActivity: activities.idActivity)
            }
        }
    }
}

// MARK: - Collection View

extension activityTableViewCell: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        // Select not permitted
        if !didSelectItemEnable {
            return
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionCell", for: indexPath) as? activityCollectionViewCell
        
        let activityPreview = activityPreviews[indexPath.row]
        
        if activityPreview.view == "trashbin" {
            
            var responder: UIResponder? = collectionView
            while !(responder is UIViewController) {
                responder = responder?.next
                if nil == responder {
                    break
                }
            }
            if (responder as? UIViewController)!.navigationController != nil {
                if let viewController = UIStoryboard.init(name: "NCTrash", bundle: nil).instantiateInitialViewController() as? NCTrash {
                    if let result = NCManageDatabase.shared.getTrashItem(fileId: String(activityPreview.fileId), account: activityPreview.account) {
                        viewController.blinkFileId = result.fileId
                        viewController.trashPath = result.filePath
                        (responder as? UIViewController)!.navigationController?.pushViewController(viewController, animated: true)
                    } else {
                        NCContentPresenter.shared.messageNotification("_error_", description: "_trash_file_not_found_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorInternalError)
                    }
                }
            }
            
            return
        }
        
        if activityPreview.view == "files" && activityPreview.mimeType != "dir" {
            
            guard let activitySubjectRich = NCManageDatabase.shared.getActivitySubjectRich(account: activityPreview.account, idActivity: activityPreview.idActivity, id: String(activityPreview.fileId)) else {
                return
            }
            
            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "fileId == %@", activitySubjectRich.id)) {
                if let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView) {
                    do {
                        let attr = try FileManager.default.attributesOfItem(atPath: filePath)
                        let fileSize = attr[FileAttributeKey.size] as! UInt64
                        if fileSize > 0 {
                            if let viewController = self.viewController {
                                NCViewer.shared.view(viewController: viewController, metadata: metadata, metadatas: [metadata], imageIcon: cell?.imageView.image)
                            }
                            return
                        }
                    } catch {
                        print("Error: \(error)")
                    }
                }
            }
            
            var pathComponents = activityPreview.link.components(separatedBy: "?")
            pathComponents = pathComponents[1].components(separatedBy: "&")
            var serverUrlFileName = pathComponents[0].replacingOccurrences(of: "dir=", with: "").removingPercentEncoding!
            serverUrlFileName = appDelegate.urlBase + "/" + NCUtilityFileSystem.shared.getWebDAV(account: activityPreview.account) + serverUrlFileName + "/" + activitySubjectRich.name
            
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(activitySubjectRich.id, fileNameView: activitySubjectRich.name)!
            
            NCUtility.shared.startActivityIndicator(backgroundView: (appDelegate.window?.rootViewController?.view)!, blurEffect: true)
            
            NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (_) in
                
            }, taskHandler: { (_) in
                
            }, progressHandler: { (_) in
                
            }) { (account, etag, date, lenght, allHeaderFields, error, errorCode, errorDescription) in
                
                if account == self.appDelegate.account && errorCode == 0 {
                    
                    let serverUrl = (serverUrlFileName as NSString).deletingLastPathComponent
                    let fileName = (serverUrlFileName as NSString).lastPathComponent
                    let serverUrlFileName = serverUrl + "/" + fileName
                    
                    NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: activityPreview.account) { (account, metadata, errorCode, errorDescription) in
                        
                        NCUtility.shared.stopActivityIndicator()
                        
                        if account == self.appDelegate.account && errorCode == 0  {
                            
                            // move from id to oc:id + instanceid (ocId)
                            let atPath = CCUtility.getDirectoryProviderStorage()! + "/" + activitySubjectRich.id
                            let toPath = CCUtility.getDirectoryProviderStorage()! + "/" + metadata!.ocId
                                                       
                            CCUtility.moveFile(atPath: atPath, toPath: toPath)
                                                       
                            NCManageDatabase.shared.addMetadata(metadata!)
                            if let viewController = self.viewController {
                                NCViewer.shared.view(viewController: viewController, metadata: metadata!, metadatas: [metadata!], imageIcon: cell?.imageView.image)
                            }
                        }
                    }
                    
                } else {
                    
                    NCUtility.shared.stopActivityIndicator()
                }
            }
        }
    }
}

extension activityTableViewCell: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return activityPreviews.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell: activityCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionCell", for: indexPath) as! activityCollectionViewCell
            
        cell.imageView.image = nil
        
        let activityPreview = activityPreviews[indexPath.row]
        let fileId = String(activityPreview.fileId)
        
        // Trashbin
        if activityPreview.view == "trashbin" {
            
            let source = activityPreview.source
            
            NCUtility.shared.convertSVGtoPNGWriteToUserData(svgUrlString: source, fileName: nil, width: 100, rewrite: false, account: appDelegate.account) { (imageNamePath) in
                if imageNamePath != nil {
                    if let image = UIImage(contentsOfFile: imageNamePath!) {
                        cell.imageView.image = image
                    }
                } else {
                     cell.imageView.image = UIImage.init(named: "file")
                }
            }
            
        } else {
            
            if activityPreview.isMimeTypeIcon {
                
                let source = activityPreview.source
                
                NCUtility.shared.convertSVGtoPNGWriteToUserData(svgUrlString: source, fileName: nil, width: 100, rewrite: false, account: appDelegate.account) { (imageNamePath) in
                    if imageNamePath != nil {
                        if let image = UIImage(contentsOfFile: imageNamePath!) {
                            cell.imageView.image = image
                        }
                    } else {
                        cell.imageView.image = UIImage.init(named: "file")
                    }
                }
                
            } else {
                
                if let activitySubjectRich = NCManageDatabase.shared.getActivitySubjectRich(account: account, idActivity: idActivity, id: fileId) {
                    
                    let fileNamePath = CCUtility.getDirectoryUserData() + "/" + activitySubjectRich.name
                    
                    if FileManager.default.fileExists(atPath: fileNamePath) {
                        
                        if let image = UIImage(contentsOfFile: fileNamePath) {
                            cell.imageView.image = image
                        }
                        
                    } else {
                        
                        NCCommunication.shared.downloadPreview(fileNamePathOrFileId: activityPreview.source, fileNamePreviewLocalPath: fileNamePath, widthPreview: 0, heightPreview: 0, useInternalEndpoint: false) { (account, imagePreview, imageIcon, errorCode, errorDescription) in
                            if errorCode == 0 && imagePreview != nil {
                                self.collectionView.reloadData()
                            }
                        }
                    }
                }
            }
        }
            
        return cell
    }
    
}

class activityCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

extension activityTableViewCell: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 50, height: 50)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
    }
}

// MARK: - NC API & Algorithm

extension NCActivity {
    
    func loadDataSource() {
        
        sectionDate.removeAll()
        
        let activities = NCManageDatabase.shared.getActivity(predicate: NSPredicate(format: "account == %@", appDelegate.account), filterFileId: filterFileId)
        allActivities = activities.all
        filterActivities = activities.filter
        for tableActivity in filterActivities {
            guard let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: tableActivity.date as Date)) else {
                continue
            }
            if !sectionDate.contains(date) {
                sectionDate.append(date)
            }
        }
        
        tableView.reloadData()
    }
    
    func getTableActivitiesFromSection(_ section: Int) -> [tableActivity] {
        let startDate = sectionDate[section]
        let endDate: Date = {
            let components = DateComponents(day: 1, second: -1)
            return Calendar.current.date(byAdding: components, to: startDate)!
        }()
        
        let activities = NCManageDatabase.shared.getActivity(predicate: NSPredicate(format: "account == %@ && date BETWEEN %@", appDelegate.account, [startDate, endDate]), filterFileId: filterFileId)
        return activities.filter
    }
    
    @objc func loadActivity(idActivity: Int) {
        
        if !canFetchActivity { return }
        canFetchActivity = false
        
        if idActivity > 0 {
            
            let height = self.tabBarController?.tabBar.frame.size.height ?? 0
            NCUtility.shared.startActivityIndicator(backgroundView: self.view, blurEffect: false, bottom: height + 50, style: .gray)
        }
        
        NCCommunication.shared.getActivity(since: idActivity, limit: 200, objectId: filterFileId, objectType: objectType, previews: true) { (account, activities, errorCode, errorDescription) in
            
           if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.shared.addActivity(activities , account: account)
            }
            
            NCUtility.shared.stopActivityIndicator()
            
            if errorCode == 304 {
                self.canFetchActivity = false
            } else {
                self.canFetchActivity = true
            }
            
            self.loadDataSource()
        }
    }
}

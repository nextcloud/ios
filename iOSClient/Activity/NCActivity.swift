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

import Foundation
import UIKit
import SwiftRichString
import NCCommunication

class NCActivity: UIViewController, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    @IBOutlet weak var tableView: UITableView!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    var allActivities: [tableActivity] = []
    var filterActivities: [tableActivity] = []

    var sectionDate: [Date] = []
    var insets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    var didSelectItemEnable: Bool = true
    var filterFileId: String?
    var objectType: String?
    
    var canFetchActivity = true
    var dateAutomaticFetch : Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.navigationController?.navigationBar.prefersLargeTitles = true
        
        self.title = NSLocalizedString("_activity_", comment: "")

        // empty Data Source
        tableView.emptyDataSetDelegate = self;
        tableView.emptyDataSetSource = self;
        
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.clear
        tableView.tableFooterView = UIView()
        tableView.contentInset = insets
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadDataSource()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        loadActivity(idActivity: 0)
    }
    
    @objc func changeTheming() {
        
        if filterFileId == nil {
            appDelegate.changeTheming(self, tableView: tableView, collectionView: nil, form: false)
        } else {
            appDelegate.changeTheming(self, tableView: tableView, collectionView: nil, form: true)
        }
    }
    
    // MARK: DZNEmpty
    
    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        if insets.top != 0 {
            return insets.top - 150
        } else {
            let height = self.tabBarController?.tabBar.frame.size.height ?? 0
            return -height
        }
    }

    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        if filterFileId == nil {
            return NCBrandColor.sharedInstance.backgroundView
        } else {
            return NCBrandColor.sharedInstance.backgroundForm
        }
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "activity"), width: 300, height: 300, color: .gray)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n" + NSLocalizedString("_no_activity_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }

    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
}

class activityTableViewCell: UITableViewCell {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var subjectTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!

    var idActivity: Int = 0
    var account: String = ""
    var activityPreviews: [tableActivityPreview] = []
    var didSelectItemEnable: Bool = true

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
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 60))
        view.backgroundColor = .clear
        
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textColor = NCBrandColor.sharedInstance.textView
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
        return getTableActivitiesFromSection(section).count
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
            cell.subject.textColor = NCBrandColor.sharedInstance.textView
            
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
            if activity.user.count > 0 && activity.user != appDelegate.userID {
                
                cell.subjectTrailingConstraint.constant = 50
                cell.avatar.isHidden = false
                
                let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-" + activity.user + ".png"
                if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                    if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                        cell.avatar.image = image
                    }
                } else {
                    DispatchQueue.global().async {
                        NCCommunication.shared.downloadAvatar(userID: activity.user, fileNameLocalPath: fileNameLocalPath, size: Int(k_avatar_size)) { (account, data, errorCode, errorMessage) in
                            if errorCode == 0 && account == self.appDelegate.account && UIImage(data: data!) != nil {
                                cell.avatar.image = UIImage(data: data!)
                            }
                        }
                    }
                }
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
                    if let result = NCManageDatabase.sharedInstance.getActivitySubjectRich(account: appDelegate.account, idActivity: activity.idActivity, key: key) {
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
            cell.activityPreviews = NCManageDatabase.sharedInstance.getActivityPreview(account: activity.account, idActivity: activity.idActivity, orderKeysId: orderKeysId)
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
        if (Int(scrollView.contentOffset.y + scrollView.frame.size.height) == Int(scrollView.contentSize.height + scrollView.contentInset.bottom)) {
            loadActivity(idActivity: allActivities.last!.idActivity)
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
                    if let result = NCManageDatabase.sharedInstance.getTrashItem(fileId: String(activityPreview.fileId), account: activityPreview.account) {
                        viewController.blinkocId = result.fileId
                        viewController.trashPath = result.filePath
                        (responder as? UIViewController)!.navigationController?.pushViewController(viewController, animated: true)
                    } else {
                        NCContentPresenter.shared.messageNotification("_error_", description: "_trash_file_not_found_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorInternalError))
                    }
                }
            }
            
            return
        }
        
        if activityPreview.view == "files" && activityPreview.mimeType != "dir" {
            
            guard let activitySubjectRich = NCManageDatabase.sharedInstance.getActivitySubjectRich(account: activityPreview.account, idActivity: activityPreview.idActivity, id: String(activityPreview.fileId)) else {
                return
            }
            
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileId == %@", activitySubjectRich.id)) {
                if let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView) {
                    do {
                        let attr = try FileManager.default.attributesOfItem(atPath: filePath)
                        let fileSize = attr[FileAttributeKey.size] as! UInt64
                        if fileSize > 0 {
                            self.appDelegate.activeMain.performSegue(withIdentifier: "segueDetail", sender: metadata)
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
            serverUrlFileName = appDelegate.urlBase + "/" + NCUtility.shared.getWebDAV(account: activityPreview.account) + serverUrlFileName + "/" + activitySubjectRich.name
            
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(activitySubjectRich.id, fileNameView: activitySubjectRich.name)!
            
            NCUtility.shared.startActivityIndicator(view: (appDelegate.window.rootViewController?.view)!)
            
            NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (_) in
                
            }, progressHandler: { (_) in
                
            }) { (account, etag, date, lenght, error, errorCode, errorDescription) in
                
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
                                                       
                            NCManageDatabase.sharedInstance.addMetadata(metadata!)
                            self.appDelegate.activeMain.performSegue(withIdentifier: "segueDetail", sender: metadata)
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
        
        if let cell: activityCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionCell", for: indexPath) as? activityCollectionViewCell {
            
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
                    
                    if let activitySubjectRich = NCManageDatabase.sharedInstance.getActivitySubjectRich(account: account, idActivity: idActivity, id: fileId) {
                        
                        let fileNamePath = CCUtility.getDirectoryUserData() + "/" + activitySubjectRich.name
                        
                        if FileManager.default.fileExists(atPath: fileNamePath) {
                            
                            if let image = UIImage(contentsOfFile: fileNamePath) {
                                cell.imageView.image = image
                            }
                            
                        } else {
                            
                            NCCommunication.shared.downloadPreview(fileNamePathOrFileId: activityPreview.source, fileNamePreviewLocalPath: fileNamePath, widthPreview: 0, heightPreview: 0, useInternalEndpoint: false) { (account, imagePreview, imageIcon, errorCode, errorDescription) in
                                if errorCode == 0 && imagePreview != nil {
                                    cell.imageView.image = imagePreview
                                }
                            }
                        }
                    }
                }
            }
            
            return cell
        }
        
        return UICollectionViewCell()
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
        
        let activities = NCManageDatabase.sharedInstance.getActivity(predicate: NSPredicate(format: "account == %@", appDelegate.account), filterFileId: filterFileId)
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
        
        let activities = NCManageDatabase.sharedInstance.getActivity(predicate: NSPredicate(format: "account == %@ && date BETWEEN %@", appDelegate.account, [startDate, endDate]), filterFileId: filterFileId)
        return activities.filter
    }
    
    @objc func loadActivity(idActivity: Int) {
        
        if !canFetchActivity { return }
        canFetchActivity = false
        
        if idActivity > 0 {
            NCUtility.shared.startActivityIndicator(view: self.view, bottom: 50)
        }
        
        NCCommunication.shared.getActivity(since: idActivity, limit: 200, objectId: filterFileId, objectType: objectType, previews: true) { (account, activities, errorCode, errorDescription) in
            
           if errorCode == 0 && account == self.appDelegate.account {
                NCManageDatabase.sharedInstance.addActivity(activities , account: account)
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

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

class NCActivity: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    @IBOutlet weak var tableView: UITableView!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    private let refreshControl = UIRefreshControl()

    var activities = [tableActivity]()
    var sectionDate = [Date]()

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // empty Data Source
        tableView.emptyDataSetDelegate = self;
        tableView.emptyDataSetSource = self;
        
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.clear
        tableView.tableFooterView = UIView()
        tableView.refreshControl = refreshControl
        
        // Configure Refresh Control
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brand
        refreshControl.addTarget(self, action: #selector(loadActivity), for: .valueChanged)
        
        self.title = NSLocalizedString("_activity_", comment: "")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Color
        appDelegate.aspectNavigationControllerBar(self.navigationController?.navigationBar, online: appDelegate.reachability.isReachable(), hidden: false)
        appDelegate.aspectTabBar(self.tabBarController?.tabBar, hidden: false)
    
        loadDataSource()
    }
    
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "activityNoRecord"), multiplier: 2, color: NCBrandColor.sharedInstance.graySoft)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n" + NSLocalizedString("_no_activity_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }

    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: TableView

    func loadDataSource() {
        
        activities = NCManageDatabase.sharedInstance.getActivity(predicate: NSPredicate(format: "account == %@", appDelegate.activeAccount))
        for tableActivity in activities {
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
        
        return NCManageDatabase.sharedInstance.getActivity(predicate: NSPredicate(format: "account == %@ && date BETWEEN %@", appDelegate.activeAccount, [startDate, endDate]))
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionDate.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getTableActivitiesFromSection(section).count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 60))
        view.backgroundColor = .clear
        
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white
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

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        print("prefetchRowsAt \(indexPaths)")
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        print("cancelPrefetchingForRowsAt \(indexPaths)")
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for: indexPath) as? activityTableViewCell {
            
            let results = getTableActivitiesFromSection(indexPath.section)
            let activity = results[indexPath.row]
            var orderKeysId = [String]()

            cell.idActivity = activity.idActivity
            cell.account = activity.account
            cell.avatar.image = nil
            cell.avatar.isHidden = true
            cell.subjectTrailingConstraint.constant = 10

            // icon
            if activity.icon.count > 0 {
                
                let fileNameIcon = (activity.icon as NSString).lastPathComponent
                let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + fileNameIcon
                
                if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                    
                    if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                        cell.icon.image = image
                    }
                    
                } else {
                    
                    DispatchQueue.global().async {
                        
                        let encodedString = activity.icon.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                        if let data = try? Data(contentsOf: URL(string: encodedString!)!) {
                            
                            DispatchQueue.main.async {
                                do {
                                    try data.write(to: fileNameLocalPath.url, options: .atomic)
                                } catch { return }
                                cell.icon.image = UIImage(data: data)
                            }
                        }
                    }
                }
            }
    
            // avatar
            if activity.user.count > 0 && activity.user != appDelegate.activeUserID {
                
                cell.subjectTrailingConstraint.constant = 50
                cell.avatar.isHidden = false
                
                let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-" + activity.user + ".png"
                if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                    if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                        cell.avatar.image = image
                    }
                } else {
                    DispatchQueue.global().async {
                        let url = self.appDelegate.activeUrl + k_avatar + activity.user + "/128"
                        let encodedString = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                        if let data = try? Data(contentsOf: URL(string: encodedString!)!) {
                            DispatchQueue.main.async {
                                do {
                                    try data.write(to: fileNameLocalPath.url, options: .atomic)
                                } catch { return }
                                cell.avatar.image = UIImage(data: data)
                            }
                        }
                    }
                }
            }
            
            // subject
            if activity.subjectRich.count > 0 {
                
                var subject = activity.subjectRich
                var keys = [String]()
                
                if let regex = try? NSRegularExpression(pattern: "\\{[a-z0-9]+\\}", options: .caseInsensitive) {
                    let string = subject as NSString
                    keys = regex.matches(in: subject, options: [], range: NSRange(location: 0, length: string.length)).map {
                        string.substring(with: $0.range).replacingOccurrences(of: "[\\{\\}]", with: "", options: .regularExpression)
                    }
                }
                
                for key in keys {
                    if let result = NCManageDatabase.sharedInstance.getActivitySubjectRich(account: appDelegate.activeAccount, idActivity: activity.idActivity, key: key) {
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
    
    // MARK: NC API
    
    @objc func loadActivity() {
        
        OCNetworking.sharedManager().getActivityWithAccount(appDelegate.activeAccount, since: Int(NCManageDatabase.sharedInstance.getActivityLastIdActivity(account: self.appDelegate.activeAccount)), limit: 100, link: "", completion: { (account, listOfActivity, message, errorCode) in
            
            self.refreshControl.endRefreshing()
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                NCManageDatabase.sharedInstance.addActivity(listOfActivity as! [OCActivity], account: account!)
                
                self.loadDataSource()
            }
        })
    }
}

class activityTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var subjectTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!

    var idActivity: Int = 0
    var account: String = ""
    var activityPreviews = [tableActivityPreview]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 50, height: 50)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
    }
    
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
            let fileID = String(activityPreview.fileId)

            // Trashbin
            if activityPreview.view == "trashbin" {
                
                let source = activityPreview.source
                
                DispatchQueue.global().async {
                    if let imageNamePath = NCUtility.sharedInstance.convertSVGtoPNGWriteToUserData(svgUrlString: source, fileName: nil, width: 100, rewrite: false) {
                        DispatchQueue.main.async {
                            if let image = UIImage(contentsOfFile: imageNamePath) {
                                cell.imageView.image = image
                            }
                        }
                    }
                }
                
            } else {
                
                if activityPreview.isMimeTypeIcon {
                    
                    let source = activityPreview.source

                    DispatchQueue.global().async {
                        if let imageNamePath = NCUtility.sharedInstance.convertSVGtoPNGWriteToUserData(svgUrlString: source, fileName: nil, width: 100, rewrite: false) {
                            DispatchQueue.main.async {
                                if let image = UIImage(contentsOfFile: imageNamePath) {
                                    cell.imageView.image = image
                                }
                            }
                        }
                    }
                    
                } else {
                    
                    if let activitySubjectRich = NCManageDatabase.sharedInstance.getActivitySubjectRich(account: account, idActivity: idActivity, id: fileID) {
                    
                        let fileNamePath = CCUtility.getDirectoryUserData() + "/" + activitySubjectRich.name
                        
                        if FileManager.default.fileExists(atPath: fileNamePath) {
                            
                            if let image = UIImage(contentsOfFile: fileNamePath) {
                                cell.imageView.image = image
                            }
                            
                        } else {
                            
                            OCNetworking.sharedManager()?.downloadPreview(withAccount: appDelegate.activeAccount, serverPath: activityPreview.source, fileNamePath: fileNamePath, completion: { (account, message, errorCode) in
                                if errorCode == 0 {
                                    if let image = UIImage(contentsOfFile: fileNamePath) {
                                        cell.imageView.image = image
                                    }
                                }
                            })
                        }
                    }
                }
            }
            
            return cell
        }
        
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
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
                    viewController.scrollToFileID = String(activityPreview.fileId)
                    (responder as? UIViewController)!.navigationController?.pushViewController(viewController, animated: true)
                }
            }
            
            return
        }
        
        if activityPreview.view == "files" && activityPreview.mimeType != "dir" {
            
            guard let activitySubjectRich = NCManageDatabase.sharedInstance.getActivitySubjectRich(account: activityPreview.account, idActivity: activityPreview.idActivity, id: String(activityPreview.fileId)) else {
                return
            }
            
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID CONTAINS %@", activitySubjectRich.id)) {
                if let filePath = CCUtility.getDirectoryProviderStorageFileID(metadata.fileID, fileNameView: metadata.fileNameView) {
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
            var url = pathComponents[0].replacingOccurrences(of: "dir=", with: "").removingPercentEncoding!
            url = appDelegate.activeUrl + k_webDAV + url + "/" + activitySubjectRich.name
            
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageFileID(activitySubjectRich.id, fileNameView: activitySubjectRich.name)
            
            NCUtility.sharedInstance.startActivityIndicator(view: (appDelegate.window.rootViewController?.view)!)
            
            let _ = OCNetworking.sharedManager()?.download(withAccount: activityPreview.account, url: url, fileNameLocalPath: fileNameLocalPath, completion: { (account, message, errorCode) in
                
                if account == self.appDelegate.activeAccount && errorCode == 0 {
                    
                    let serverUrl = (url as NSString).deletingLastPathComponent
                    let fileName = (url as NSString).lastPathComponent
                    
                    OCNetworking.sharedManager()?.readFile(withAccount: activityPreview.account, serverUrl: serverUrl, fileName: fileName, completion: { (account, metadata, message, errorCode) in
                        
                        NCUtility.sharedInstance.stopActivityIndicator()

                        if account == self.appDelegate.activeAccount && errorCode == 0 {
                            
                            // move from id to oc:id + instanceid (fileID)
                            
                            let atPath = CCUtility.getDirectoryProviderStorage()! + "/" + activitySubjectRich.id
                            let toPath = CCUtility.getDirectoryProviderStorage()! + "/" + metadata!.fileID
                            
                            CCUtility.moveFile(atPath: atPath, toPath: toPath)
                            
                            if let metadata = NCManageDatabase.sharedInstance.addMetadata(metadata!) {
                                self.appDelegate.activeMain.performSegue(withIdentifier: "segueDetail", sender: metadata)
                            }
                        }
                    })
                    
                } else {
                    
                    NCUtility.sharedInstance.stopActivityIndicator()
                }
            })
        }
    }
}

class activityCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

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

class NCActivity: UIViewController, UITableViewDataSource, UITableViewDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    @IBOutlet weak var tableView: UITableView!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
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
        
        self.title = NSLocalizedString("_activity_", comment: "")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Color
        appDelegate.aspectNavigationControllerBar(self.navigationController?.navigationBar, online: appDelegate.reachability.isReachable(), hidden: false)
        appDelegate.aspectTabBar(self.tabBarController?.tabBar, hidden: false)
    
        loadDatasource()
    }
    
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "activityNoRecord"), multiplier: 2, color: NCBrandColor.sharedInstance.graySoft)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_no_activity_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }

    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    func loadDatasource() {
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
    
    // MARK: TableView

    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionDate.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let startDate = sectionDate[section]
        let endDate: Date = {
            let components = DateComponents(day: 1, second: -1)
            return Calendar.current.date(byAdding: components, to: startDate)!
        }()
        
        let results = NCManageDatabase.sharedInstance.getActivity(predicate: NSPredicate(format: "account == %@ && date BETWEEN %@", appDelegate.activeAccount, [startDate, endDate]))
        return results.count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 30))
        view.backgroundColor = UIColor.white
        let label = UILabel(frame: CGRect(x: 55, y: 0, width: tableView.bounds.width - 55, height: 30))
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.textColor = UIColor.black
        label.text = CCUtility.getTitleSectionDate(sectionDate[section])
        view.addSubview(label)
        return view
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for: indexPath) as? activityTableViewCell {
            
            //
            let startDate = sectionDate[indexPath.section]
            let endDate: Date = {
                let components = DateComponents(day: 1, second: -1)
                return Calendar.current.date(byAdding: components, to: startDate)!
            }()
            
            let results = NCManageDatabase.sharedInstance.getActivity(predicate: NSPredicate(format: "account == %@ && date BETWEEN %@", appDelegate.activeAccount, [startDate, endDate]))
            //
            
            let activity = results[indexPath.row]

            cell.idActivity = activity.idActivity
            cell.account = activity.account
            cell.avatar.image = nil
            cell.avatar.isHidden = true

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
            if activity.user.count > 0 {
                
                if activity.user == appDelegate.activeUserID {
                    
                    cell.subjectTrailingConstraint.constant = 10
                    
                } else {
                
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
            }
            
            // subject
            if activity.subjectRich.count > 0 {
                
                var subject = activity.subjectRich
                
                let keys = subject.keyTags()
                for key in keys {
                    if let result = NCManageDatabase.sharedInstance.getActivitySubjectRich(account: appDelegate.activeAccount, idActivity: activity.idActivity, key: key) {
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
            
            cell.collectionView.reloadData()

            return cell
        }
        
        return UITableViewCell()
    }
}

class activityTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var subjectTrailingConstraint: NSLayoutConstraint!

    var idActivity: Int = 0
    var account: String = ""
    var activityPreviews = [tableActivityPreview]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = CGSize(width: 50, height: 50)
        return size
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        activityPreviews = NCManageDatabase.sharedInstance.getActivityPreview(account: account, idActivity: idActivity)
        return activityPreviews.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
      
        if let cell: activityCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionCell", for: indexPath) as? activityCollectionViewCell {
            
            cell.imageView.image = nil
            
            let activityPreview = activityPreviews[indexPath.row]
            let fileID = String(activityPreview.fileId)

            // Trashbin
            if activityPreview.view == "trashbin" {
                
                if let activitySubjectRich = NCManageDatabase.sharedInstance.getActivitySubjectRich(account: account, idActivity: idActivity, id: fileID) {

                    let fileName = activitySubjectRich.name
                    
                    if activityPreview.mimeType == "dir" {
                        
                        cell.imageView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                        
                    } else {
                        if CCUtility.fileProviderStorageIconExists(fileID, fileNameView: activitySubjectRich.name) {
                            if let image = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(fileID, fileNameView: fileName)) {
                                cell.imageView.image = image
                            }
                        } else {
                            OCNetworking.sharedManager().downloadPreviewTrash(withAccount: appDelegate.activeAccount, fileID: fileID, fileName: fileName, completion: { (account, message, errorCode) in
                                if errorCode == 0 && account == self.appDelegate.activeAccount && CCUtility.fileProviderStorageIconExists(fileID, fileNameView: fileName) {
                                    if let image = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(fileID, fileNameView: fileName)) {
                                        cell.imageView.image = image
                                    }
                                } else {
                                    print(errorCode)
                                }
                            })
                        }
                    }
                }
                
            } else {
                
                if activityPreview.isMimeTypeIcon {
                    DispatchQueue.global().async {
                        if let imageNamePath = NCUtility.sharedInstance.convertSVGtoPNGWriteToUserData(svgUrlString: activityPreview.source, fileName: nil, width: 100, rewrite: false) {
                            DispatchQueue.main.async {
                                if let image = UIImage(contentsOfFile: imageNamePath) {
                                    cell.imageView.image = image
                                }
                            }
                        }
                    }
                } else {
                    
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

// MARK: Extension

extension String
{
    func keyTags() -> [String] {
        if let regex = try? NSRegularExpression(pattern: "\\{[a-z0-9]+\\}", options: .caseInsensitive) {
            let string = self as NSString
            return regex.matches(in: self, options: [], range: NSRange(location: 0, length: string.length)).map {
                string.substring(with: $0.range).replacingOccurrences(of: "[\\{\\}]", with: "", options: .regularExpression)
            }
        }
        return []
    }
}

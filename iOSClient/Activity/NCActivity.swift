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
    var datasource = [tableActivity]()
    var sectionDate = [Date]()

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // empty Data Source
        tableView.emptyDataSetDelegate = self;
        tableView.emptyDataSetSource = self;
        
        tableView.estimatedRowHeight = 120
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
        datasource = NCManageDatabase.sharedInstance.getActivity(predicate: NSPredicate(format: "account == %@", appDelegate.activeAccount))
        for tableActivity in datasource {
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
        return 100
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? activityTableViewCell {
            
            let tableActivity = datasource[indexPath.row]
            
            // icon
            if tableActivity.icon.count > 0 {
                let fileNameIcon = (tableActivity.icon as NSString).lastPathComponent
                let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + fileNameIcon
                if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                    if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                        cell.icon.image = image
                    }
                } else {
                    DispatchQueue.global().async {
                        let encodedString = tableActivity.icon.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
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
            if tableActivity.user.count > 0 {
                let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-" + tableActivity.user + ".png"
                if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                    if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                        cell.avatar.image = image
                    }
                } else {
                    DispatchQueue.global().async {
                        let url = self.appDelegate.activeUrl + k_avatar + tableActivity.user + "/128"
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
            if tableActivity.subjectRich.count > 0 {
                
                var subject = tableActivity.subjectRich
                
                let keys = subject.keyTags()
                for key in keys {
                    if let result = NCManageDatabase.sharedInstance.getActivitySubjectRich(account: appDelegate.activeAccount, idActivity: tableActivity.idActivity, key: key) {
                        subject = subject.replacingOccurrences(of: "{\(key)}", with: "<bold>" + result.name + "</bold>")
                    }
                }
                
                let normal = Style { $0.font = UIFont.systemFont(ofSize: cell.subject.font.pointSize) }
                let bold = Style { $0.font = UIFont.systemFont(ofSize: cell.subject.font.pointSize, weight: .bold) }
                let date = Style { $0.font = UIFont.systemFont(ofSize: cell.subject.font.pointSize - 3)
                    $0.color = UIColor.lightGray
                }
                
                subject = subject + "\n" + "<date>" + CCUtility.dateDiff(tableActivity.date as Date) + "</date>"
                cell.subject.attributedText = subject.set(style: StyleGroup(base: normal, ["bold": bold, "date": date]))
                
                //
            }
            
            return cell
        }
        
        return UITableViewCell()
    }
}

class activityTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var subject: UILabel!

    var imageArray = [String] ()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        imageArray = ["1.jpeg","2.jpeg","3.jpeg","4.jpeg","5.jpeg","6.jpeg","7.jpeg","8.jpeg","9.jpeg","10.jpeg"]
        
        // Initialization code
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize{
        let size = CGSize(width: 120, height: 120)
        return size
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
      
        if let cell: activityCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as? activityCollectionViewCell {
            let randomNumber = Int(arc4random_uniform(UInt32(imageArray.count)))
            cell.imageView.image = UIImage(named: imageArray[randomNumber])
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

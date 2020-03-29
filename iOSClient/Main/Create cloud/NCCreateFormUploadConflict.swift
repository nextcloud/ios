//
//  NCCreateFormUploadConflict.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/03/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

@objc class NCCreateFormUploadConflict: UIViewController {

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelSubTitle: UILabel!

    @IBOutlet weak var switchNewFiles: UISwitch!
    @IBOutlet weak var switchAlreadyExistingFiles: UISwitch!

    @IBOutlet weak var labelNewFiles: UILabel!
    @IBOutlet weak var labelAlreadyExistingFiles: UILabel!

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var buttonCancel: UIButton!
    @IBOutlet weak var buttonContinue: UIButton!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    @objc var metadatas: [tableMetadata]
    @objc var metadatasConflict: [tableMetadata]

    @objc required init?(coder aDecoder: NSCoder) {
        self.metadatas = [tableMetadata]()
        self.metadatasConflict = [tableMetadata]()
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.register(UINib.init(nibName: "NCCreateFormUploadConflictCell", bundle: nil), forCellReuseIdentifier: "Cell")
    }
}

// MARK: - UITableViewDelegate

extension NCCreateFormUploadConflict: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}

// MARK: - UITableViewDataSource

extension NCCreateFormUploadConflict: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return metadatas.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? NCCreateFormUploadConflictCell {
            
            let metadata = metadatas[indexPath.row]
            
            cell.labelFileName.text = metadata.fileNameView
            
            return cell
        }
        
        return UITableViewCell()
    }
}

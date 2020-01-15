//
//  NCViewerRichWorkspace.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/01/2020.
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

@objc class NCViewerRichWorkspace: UIViewController {

    @IBOutlet weak var viewRichWorkspace: NCViewRichWorkspace!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    @objc public var richWorkspace: String = ""
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let editItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(editButtonTapped(_:)))
        self.navigationItem.leftBarButtonItem = editItem
        
        viewRichWorkspace.setRichWorkspaceText(richWorkspace)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        changeTheming()
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: nil, form: false)
    }
    
    @objc func editButtonTapped(_ sender: UIBarButtonItem)
    {
        self.dismiss(animated: false, completion: nil)
    }
}

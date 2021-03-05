//
//  NCRenameFile.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
import NCCommunication

class NCAccountRequest: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    
    public var accounts: [tableAccount] = []
    
    private var timer: Timer?
    private var time: Float = 0
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = NSLocalizedString("_account_request_", comment: "")
        
        okButton.setTitle(NSLocalizedString("_ok_", comment: ""), for: .normal)
        okButton.setTitleColor(NCBrandColor.shared.brandText, for: .normal)
        okButton.layer.cornerRadius = 15
        okButton.layer.masksToBounds = true
        okButton.layer.backgroundColor = NCBrandColor.shared.brand.cgColor
        
        progressView.tintColor = NCBrandColor.shared.brandElement
        progressView.trackTintColor = .clear
        progressView.progress = 1
        
        NotificationCenter.default.addObserver(self, selector: #selector(startTimer), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
     
    // MARK: - Progress
    
    @objc func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateProgress), userInfo: nil, repeats: true)
    }
    
    @objc func updateProgress() {
        
        time += 0.1
        
        if time >= 3 {
            timer?.invalidate()
            dismiss(animated: true)
        } else {
            progressView.progress = 1 - (time / 3)
        }
    }
    
    // MARK: - Action
    
    @IBAction func ok(_ sender: Any) {
        dismiss(animated: true)
    }
}

extension NCAccountRequest: UITableViewDelegate {
    
}

extension NCAccountRequest: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }    
}

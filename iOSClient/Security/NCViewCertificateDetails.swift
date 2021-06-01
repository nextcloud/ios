//
//  NCViewCertificateDetails.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/06/21.
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

import UIKit

class NCViewCertificateDetails: UIViewController {

    @IBOutlet weak var buttonCancel: UIBarButtonItem!
    @IBOutlet weak var textView: UITextView!

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = NSLocalizedString("_certificate_details_", comment: "")
        
        buttonCancel.title = NSLocalizedString("_close_", comment: "")
        
        let directoryCertificate = CCUtility.getDirectoryCerificates()!
        let certificatePath = directoryCertificate + "/" + NCGlobal.shared.certificateTmpV2 + ".txt"
        if FileManager.default.fileExists(atPath: certificatePath) {
            do {
                let text = try String(contentsOfFile: certificatePath, encoding: .utf8)
                textView.text = text
            } catch {
                print("error")
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    // MARK: ACTION
    
    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

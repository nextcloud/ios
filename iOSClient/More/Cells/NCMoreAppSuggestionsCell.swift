//
//  NCMoreAppSuggestionsCell.swift
//  Nextcloud
//
//  Created by Milen on 14.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
import SafariServices
import SwiftUI

class NCMoreAppSuggestionsCell: BaseNCMoreCell {
    @IBOutlet weak var assistantView: UIStackView!
    @IBOutlet weak var talkView: UIStackView!
    @IBOutlet weak var notesView: UIStackView!
    @IBOutlet weak var moreAppsView: UIStackView!

    static let reuseIdentifier = "NCMoreAppSuggestionsCell"
    var controller: NCMainTabBarController?

    static func fromNib() -> UINib {
        return UINib(nibName: "NCMoreAppSuggestionsCell", bundle: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear

        assistantView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(assistantTapped)))
        talkView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(talkTapped)))
        notesView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(notesTapped)))
        moreAppsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(moreAppsTapped)))
    }

    override func setupCell(account: String) {
        assistantView.isHidden = !NCCapabilities.shared.getCapabilities(account: account).capabilityAssistantEnabled
    }

    @objc func assistantTapped() {
        if let viewController = self.window?.rootViewController {
            let assistant = NCAssistant().environmentObject(NCAssistantTask(controller: controller))
            let hostingController = UIHostingController(rootView: assistant)
            viewController.present(hostingController, animated: true, completion: nil)
        }
    }

    @objc func talkTapped() {
        guard let url = URL(string: NCGlobal.shared.talkSchemeUrl) else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            guard let url = URL(string: NCGlobal.shared.talkAppStoreUrl) else { return }
            UIApplication.shared.open(url)
        }
    }

    @objc func notesTapped() {
        guard let url = URL(string: NCGlobal.shared.notesSchemeUrl) else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            guard let url = URL(string: NCGlobal.shared.notesAppStoreUrl) else { return }
            UIApplication.shared.open(url)
        }
    }

    @objc func moreAppsTapped() {
        guard let url = URL(string: NCGlobal.shared.moreAppsUrl) else { return }
        UIApplication.shared.open(url)
    }
}

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

import UIKit
import NextcloudKit
import MarkdownKit

@objc class NCViewerRichWorkspace: UIViewController, UIAdaptivePresentationControllerDelegate {

    @IBOutlet weak var textView: UITextView!

    private let richWorkspaceCommon = NCRichWorkspaceCommon()
    private var markdownParser = MarkdownParser()
    private var textViewColor: UIColor?

    var richWorkspaceText: String = ""
    var serverUrl: String = ""
    var delegate: NCCollectionViewCommon?

    var session: NCSession.Session {
        NCSession.shared.getSession(controller: self.delegate?.tabBarController)
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.tintColor = NCBrandColor.shared.iconImageColor
        presentationController?.delegate = self

        let closeItem = UIBarButtonItem(title: NSLocalizedString("_back_", comment: ""), style: .plain, target: self, action: #selector(closeItemTapped(_:)))
        self.navigationItem.leftBarButtonItem = closeItem

        let editItem = UIBarButtonItem(image: NCUtility().loadImage(named: "square.and.pencil"), style: UIBarButtonItem.Style.plain, target: self, action: #selector(editItemAction(_:)))
        self.navigationItem.rightBarButtonItem = editItem

        markdownParser = MarkdownParser(font: UIFont.systemFont(ofSize: 15), color: NCBrandColor.shared.textColor)
        markdownParser.header.font = UIFont.systemFont(ofSize: 25)
        textView.attributedText = markdownParser.parse(richWorkspaceText)
        textViewColor = NCBrandColor.shared.textColor
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NCNetworking.shared.readFile(serverUrlFileName: self.serverUrl, account: session.account, queue: .main) { _ in
        } completion: { account, metadata, error in
            if error == .success, let metadata {
                NCManageDatabase.shared.updateDirectoryRichWorkspace(metadata.richWorkspace, account: account, serverUrl: self.serverUrl)
                if self.richWorkspaceText != metadata.richWorkspace, metadata.richWorkspace != nil {
                    self.delegate?.richWorkspaceText = self.richWorkspaceText
                    self.richWorkspaceText = metadata.richWorkspace!
                    self.textView.attributedText = self.markdownParser.parse(metadata.richWorkspace!)
                }
            }
        }
    }

    public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        self.viewDidAppear(true)
    }

    @objc func closeItemTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: false, completion: nil)
    }

    @IBAction func editItemAction(_ sender: Any) {
        richWorkspaceCommon.openViewerNextcloudText(serverUrl: serverUrl, viewController: self, session: session)
    }
}

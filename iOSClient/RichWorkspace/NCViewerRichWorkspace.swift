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
import NCCommunication
import MarkdownKit

@objc class NCViewerRichWorkspace: UIViewController, UIAdaptivePresentationControllerDelegate {

    @IBOutlet weak var textView: UITextView!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private let richWorkspaceCommon = NCRichWorkspaceCommon()
    private var markdownParser = MarkdownParser()
    private var textViewColor: UIColor?

    @objc public var richWorkspaceText: String = ""
    @objc public var serverUrl: String = ""

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = NCBrandColor.shared.systemBackground
        presentationController?.delegate = self

        let closeItem = UIBarButtonItem(title: NSLocalizedString("_back_", comment: ""), style: .plain, target: self, action: #selector(closeItemTapped(_:)))
        self.navigationItem.leftBarButtonItem = closeItem

        let editItem = UIBarButtonItem(image: UIImage(named: "actionSheetModify"), style: UIBarButtonItem.Style.plain, target: self, action: #selector(editItemAction(_:)))
        self.navigationItem.rightBarButtonItem = editItem

        markdownParser = MarkdownParser(font: UIFont.systemFont(ofSize: 15), color: NCBrandColor.shared.label)
        markdownParser.header.font = UIFont.systemFont(ofSize: 25)
        textView.attributedText = markdownParser.parse(richWorkspaceText)
        textViewColor = NCBrandColor.shared.label
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NCNetworking.shared.readFile(serverUrlFileName: serverUrl, account: appDelegate.account) { account, metadata, errorCode, _ in

            if errorCode == 0 && account == self.appDelegate.account {
                guard let metadata = metadata else { return }
                NCManageDatabase.shared.setDirectory(richWorkspace: metadata.richWorkspace, serverUrl: self.serverUrl, account: account)
                if self.richWorkspaceText != metadata.richWorkspace && metadata.richWorkspace != nil {
                    self.appDelegate.activeFiles?.richWorkspaceText = self.richWorkspaceText
                    self.richWorkspaceText = metadata.richWorkspace!
                    DispatchQueue.main.async {
                        self.textView.attributedText = self.markdownParser.parse(metadata.richWorkspace!)
                    }
                }
            }
        }
    }

    public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        self.viewWillAppear(true)
    }

    @objc func closeItemTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: false, completion: nil)
    }

    @IBAction func editItemAction(_ sender: Any) {

        richWorkspaceCommon.openViewerNextcloudText(serverUrl: serverUrl, viewController: self)
    }
}

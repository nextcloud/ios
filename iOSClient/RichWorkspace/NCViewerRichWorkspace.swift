// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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

    @MainActor
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: self.delegate?.tabBarController)
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
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

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            let resultsReadFile = await NCNetworking.shared.readFileAsync(serverUrlFileName: self.serverUrl, account: session.account)
            guard resultsReadFile.error == .success, let metadata = resultsReadFile.metadata else {
                return
            }

            await NCManageDatabase.shared.updateDirectoryRichWorkspaceAsync(metadata.richWorkspace, account: session.account, serverUrl: self.serverUrl)

            if self.richWorkspaceText != metadata.richWorkspace, metadata.richWorkspace != nil {
                self.delegate?.richWorkspaceText = self.richWorkspaceText
                self.richWorkspaceText = metadata.richWorkspace!
                self.textView.attributedText = self.markdownParser.parse(metadata.richWorkspace!)
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

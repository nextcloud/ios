//
//  NCSharePaging.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import SwiftUI
import NextcloudKit
import NextcloudKitUI
import TagListView

protocol NCSharePagingContent {
    var textField: UIView? { get }
}

class NCSharePaging: UIViewController {
    private weak var appDelegate = UIApplication.shared.delegate as? AppDelegate
    private let tabModel = NCSharePagingTabModel()
    private weak var headerView: NCShareHeader?
    private var pageVCs: [UIViewController] = []
    private var contentHost: UIHostingController<NCSharePagingContentView>?

    /// Minimum server version that serves the unified sharing UI (plus button + Sharing tab).
    private static let unifiedSharingMinVersion: NextcloudVersion = .v34

    var metadata = tableMetadata()
    var controller: NCMainTabBarController?
    var pages: [NCBrandOptions.NCInfoPagingTab] = []

    private var initialPage: NCBrandOptions.NCInfoPagingTab = .activity
    var page: NCBrandOptions.NCInfoPagingTab {
        get {
            guard isViewLoaded else { return initialPage }
            let index = tabModel.selection
            return (index < pages.count) ? pages[index] : initialPage
        }
        set {
            initialPage = newValue
            if isViewLoaded, let index = pages.firstIndex(of: newValue) {
                tabModel.selection = index
            }
        }
    }

    private var currentVC: NCSharePagingContent? {
        let index = tabModel.selection
        guard index < pageVCs.count else { return nil }
        return pageVCs[index] as? NCSharePagingContent
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = NSLocalizedString("_details_", comment: "")

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(exitTapped(_:))
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = NSLocalizedString("_close_", comment: "")

        let manageTagsAction = UIAction(title: NSLocalizedString("_edit_tags_", comment: ""), image: UIImage(systemName: "tag")) { [weak self] _ in
            self?.editTagsTapped(nil)
        }

        let moreButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: nil, action: nil)
        moreButton.menu = UIMenu(children: [manageTagsAction])

        var rightBarButtonItems = [moreButton]

        // The unified share (+) button only applies to servers with the new sharing API.
        let capabilities = NCNetworking.shared.capabilities[metadata.account] ?? NKCapabilities.Capabilities()

        if NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: Self.unifiedSharingMinVersion) {
            let addShareButton = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(addShareTapped(_:)))
            addShareButton.accessibilityLabel = NSLocalizedString("_share_", comment: "")
            rightBarButtonItems.insert(addShareButton, at: 0)
        }

        navigationItem.rightBarButtonItems = rightBarButtonItems

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)

        setupHeader()

        pageVCs = pages.map { makeViewController(for: $0) }
        tabModel.selection = pages.firstIndex(of: initialPage) ?? 0

        setupContent()
    }

    private func setupHeader() {
        guard let headerView = Bundle.main.loadNibNamed("NCShareHeader", owner: self, options: nil)?.first as? NCShareHeader else { return }
        self.headerView = headerView
        headerView.backgroundColor = .systemBackground
        headerView.setupUI(with: metadata)

        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
    }

    private func setupContent() {
        let content = NCSharePagingContentView(
            model: tabModel,
            tint: Color(NCBrandColor.shared.getElement(account: metadata.account)),
            titles: pages.map(titleForTab(_:)),
            pageVCs: pageVCs,
            onSelectionChange: { [weak self] _ in
                self?.view.endEditing(true)
            }
        )
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .systemBackground

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        host.view.translatesAutoresizingMaskIntoConstraints = false

        let topAnchor = headerView?.bottomAnchor ?? view.safeAreaLayoutGuide.topAnchor
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])

        self.contentHost = host
    }

    private func makeViewController(for tab: NCBrandOptions.NCInfoPagingTab) -> UIViewController {
        // The old Parchment menu floated over the child view, so children inset by menuHeight (50).
        // The new SwiftUI layout places the picker above the content, so no inset is needed.
        let height: CGFloat = 0

        switch tab {
        case .activity:
            guard let viewController = UIStoryboard(name: "NCActivity", bundle: nil).instantiateInitialViewController() as? NCActivity else {
                return UIViewController()
            }
            viewController.height = height
            viewController.showComments = true
            viewController.didSelectItemEnable = false
            viewController.metadata = metadata
            viewController.objectType = "files"
            viewController.account = metadata.account
            return viewController
        case .sharing:
            let capabilities = NCNetworking.shared.capabilities[metadata.account] ?? NKCapabilities.Capabilities()

            // The unified share tab fully replaces the legacy NCShare UI on newer servers.
            if NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: Self.unifiedSharingMinVersion) {
                return UIHostingController(rootView: UnifiedShareView(fileName: metadata.fileNameView, account: metadata.account))
            }

            guard let viewController = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "sharing") as? NCShare else {
                return UIViewController()
            }
            viewController.metadata = metadata
            viewController.height = height
            viewController.controller = controller
            return viewController
        }
    }

    private func titleForTab(_ tab: NCBrandOptions.NCInfoPagingTab) -> String {
        switch tab {
        case .activity: return NSLocalizedString("_activity_", comment: "")
        case .sharing: return NSLocalizedString("_sharing_", comment: "")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarAppearance()

        let capabilities = NCNetworking.shared.capabilities[metadata.account] ?? NKCapabilities.Capabilities()

        if !capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty {
            self.dismiss(animated: false, completion: nil)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Task {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferReloadDataSource(serverUrl: self.metadata.serverUrl, requestData: false, status: nil)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.currentVC?.textField?.resignFirstResponder()
    }

    // MARK: - NotificationCenter & Keyboard & TextField

    @objc func keyboardWillShow(notification: Notification) {
         let frameEndUserInfoKey = UIResponder.keyboardFrameEndUserInfoKey

         guard let info = notification.userInfo,
               let textField = currentVC?.textField,
               let centerObject = textField.superview?.convert(textField.center, to: nil),
               let keyboardFrame = info[frameEndUserInfoKey] as? CGRect
         else { return }

        let diff = keyboardFrame.origin.y - centerObject.y - textField.frame.height
         if diff < 0 {
             view.frame.origin.y = diff
         }
     }

    @objc func keyboardWillHide(notification: NSNotification) {
        view.frame.origin.y = 0
    }

    @objc func exitTapped(_ sender: Any?) {
        self.dismiss(animated: true, completion: nil)
    }

    @objc private func addShareTapped(_ sender: UIBarButtonItem) {
        let viewController = UIHostingController(rootView: UnifiedShareEditView(fileName: metadata.fileNameView, account: metadata.account))
        viewController.modalPresentationStyle = .pageSheet

        if let sheet = viewController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        present(viewController, animated: true)
    }

    @objc func editTagsTapped(_ sender: Any?) {
        guard let header = headerView else { return }

        header.presentTagEditor(from: self) { [weak self] tags in
            guard let self else { return }
            self.metadata.tags.removeAll()
            self.metadata.tags.append(objectsIn: tags, account: self.metadata.account)
        }
    }

    @objc func applicationDidEnterBackground(notification: Notification) {
        self.dismiss(animated: false, completion: nil)
    }
}

// MARK: - SwiftUI tab content

@Observable
final class NCSharePagingTabModel {
    var selection: Int = 0
}

struct NCSharePagingContentView: View {
    @Bindable var model: NCSharePagingTabModel
    let tint: Color
    let titles: [String]
    let pageVCs: [UIViewController]
    var onSelectionChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $model.selection) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    Text(title).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .tint(tint)

            TabView(selection: $model.selection) {
                ForEach(Array(pageVCs.enumerated()), id: \.offset) { index, viewController in
                    NCViewControllerRepresentable(viewController: viewController)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onChange(of: model.selection) { _, newValue in
            onSelectionChange(newValue)
        }
    }
}

private struct NCViewControllerRepresentable: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

//
//  NCCollectionViewCommonSelectionTabBar.swift
//  Nextcloud
//
//  Created by Milen on 01.02.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import SwiftUI

protocol NCTabBarSelectDelegate: AnyObject {
    func selectAll()
    func delete(selectedMetadatas: [tableMetadata])
    func move(selectedMetadatas: [tableMetadata])
    func share(selectedMetadatas: [tableMetadata])
    func download(selectedMetadatas: [tableMetadata], isAnyOffline: Bool)
    func lock(selectedMetadatas: [tableMetadata], isAnyLocked: Bool)
//    func unselect(tabBarSelect: NCCollectionViewCommonSelectTabBar, animation: Bool)
}

class NCCollectionViewCommonSelectTabBar: ObservableObject {
    private var tabBarController: UITabBarController?
    private var hostingController: UIViewController?
    open weak var delegate: NCTabBarSelectDelegate?

    var selectedMetadatas: [tableMetadata] = []
//    var appDelegate: AppDelegate!
//
//    var selectOcId: [String] = [] {
//        didSet {
//            var selectedMetadatas: [tableMetadata] = []
//
//            for ocId in selectOcId {
//                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { continue }
//                selectedMetadatas.append(metadata)
//                if metadata.directory { isAnyFolder = true }
//                if metadata.lock {
//                    isAnyLocked = true
//                    if metadata.lockOwner != appDelegate.userId {
//                        canUnlock = false
//                    }
//                }
//
//                guard !isAnyOffline else { continue }
//                if metadata.directory,
//                   let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, metadata.serverUrl + "/" + metadata.fileName)) {
//                    isAnyOffline = directory.offline
//                } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
//                    isAnyOffline = localFile.offline
//                } // else: file is not offline, continue
//            }
//        }
//    }
//    var selectedMediaMetadatas: [tableMetadata] = []
    @Published var isAnyOffline = false
    @Published var isAnyFolder = false
    @Published var isAnyLocked = false
    @Published var canUnlock = true
    @Published var enableLock = false
    @Published var isSelectedEmpty = true

    init(tabBarController: UITabBarController? = nil, height: CGFloat = 83, delegate: NCTabBarSelectDelegate? = nil) {
        guard let tabBarController else { return }

        let hostingController = UIHostingController(rootView: MediaTabBarSelectView(height: height, tabBarSelect: self))

        self.tabBarController = tabBarController
        self.hostingController = hostingController
        self.delegate = delegate

        tabBarController.addChild(hostingController)
        tabBarController.view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor).isActive = true
        hostingController.view.rightAnchor.constraint(equalTo: tabBarController.view.rightAnchor).isActive = true
        hostingController.view.leftAnchor.constraint(equalTo: tabBarController.view.leftAnchor).isActive = true
        hostingController.view.heightAnchor.constraint(equalToConstant: height).isActive = true
        hostingController.view.backgroundColor = .clear

        hostingController.view.isHidden = true
    }

    func show(animation: Bool) {
        guard let tabBarController, let hostingController else { return }

        tabBarController.tabBar.isHidden = true
        hostingController.view.isHidden = false
    }

    func hide(animation: Bool) {
        guard let tabBarController, let hostingController else { return }

        hostingController.view.isHidden = true
        tabBarController.tabBar.isHidden = false
    }
}

struct MediaTabBarSelectView: View {
    let height: CGFloat
    @ObservedObject var tabBarSelect: NCCollectionViewCommonSelectTabBar

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button {
                    tabBarSelect.delegate?.share(selectedMetadatas: tabBarSelect.selectedMetadatas)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty)

                Button {
                    tabBarSelect.delegate?.move(selectedMetadatas: tabBarSelect.selectedMetadatas)
                } label: {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                }
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty)

                Button {
                    tabBarSelect.delegate?.delete(selectedMetadatas: tabBarSelect.selectedMetadatas)
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .frame(maxWidth: .infinity)
                .disabled(tabBarSelect.isSelectedEmpty)

                Menu("", systemImage: "ellipsis.circle") {
                    Button(action: {
                        tabBarSelect.delegate?.delete(selectedMetadatas: tabBarSelect.selectedMetadatas)
                    }, label: {
                        Label(NSLocalizedString("_download_", comment: ""), systemImage: "icloud.and.arrow.down")
                    })
                    .disabled(tabBarSelect.isSelectedEmpty)

                    Button(action: {
                        tabBarSelect.delegate?.lock(selectedMetadatas: tabBarSelect.selectedMetadatas, isAnyLocked: tabBarSelect.isAnyLocked)
                    }, label: {
                        Label(NSLocalizedString(tabBarSelect.isAnyLocked ? "_unlock_" : "_lock_", comment: ""), systemImage: tabBarSelect.isAnyLocked ? "lock.open" : "lock")

                        if !tabBarSelect.enableLock {
                            Text(NSLocalizedString("_lock_no_permissions_selected_", comment: ""))
                        }
                    })
                    .disabled(!tabBarSelect.enableLock || tabBarSelect.isSelectedEmpty)

                    Button(action: {
                        tabBarSelect.delegate?.selectAll()
                    }, label: {
                        Label(NSLocalizedString("_select_all_", comment: ""), systemImage: "checkmark")
                    })
                }
                .frame(maxWidth: .infinity)
            }

            Spacer().frame(height: 20)
        }
        .frame(height: height)
        .background(.thinMaterial)
        .overlay(Rectangle().frame(width: nil, height: 0.5, alignment: .top).foregroundColor(Color(UIColor.separator)), alignment: .top)
    }
}

#Preview {
    MediaTabBarSelectView(height: 83, tabBarSelect: NCCollectionViewCommonSelectTabBar())
}

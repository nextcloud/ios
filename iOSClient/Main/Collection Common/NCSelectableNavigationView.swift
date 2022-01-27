//
//  NCSelectableNavigationView.swift
//  Nextcloud
//
//  Created by Henrik Storch on 27.01.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
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

import Foundation
import NCCommunication
import Realm

extension RealmSwiftObject {
    var primaryKeyValue: String? {
        guard let primaryKeyName = self.objectSchema.primaryKeyProperty?.name else { return nil }
        return value(forKey: primaryKeyName) as? String
    }
}

protocol NCSelectableNavigationView: AnyObject {
    var appDelegate: AppDelegate { get }
    var selectableDataSource: [RealmSwiftObject] { get }
    var collectionView: UICollectionView! { get set }
    var isEditMode: Bool { get set }
    var selectOcId: [String] { get set }
    var titleCurrentFolder: String { get }
    var navigationItem: UINavigationItem { get }

    func tapSelectMenu()
    func tapSelect()
    func setNavigationItem()
}

extension NCSelectableNavigationView {
    func setNavigationItem() { setNavigationHeader() }

    func setNavigationHeader() {
        if isEditMode {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "navigationMore"), style: .plain, action: tapSelectMenu)
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain, action: tapSelect)
            navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(selectableDataSource.count)"
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_select_", comment: ""), style: UIBarButtonItem.Style.plain, action: tapSelect)
            navigationItem.leftBarButtonItem = nil
            navigationItem.title = titleCurrentFolder
        }
    }

    func tapSelect() {
        isEditMode = !isEditMode
        selectOcId.removeAll()
        self.setNavigationItem()
        self.collectionView.reloadData()
    }

    func collectionViewSelectAll() {
        selectOcId = selectableDataSource.compactMap({ $0.primaryKeyValue })
        navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(selectableDataSource.count)"
        collectionView.reloadData()
    }
}

extension NCSelectableNavigationView where Self: UIViewController {
    func tapSelectMenu() {

        var actions = [NCMenuAction]()

        //
        // SELECT ALL
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_select_all_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "checkmark.circle.fill"),
                action: { _ in
                    self.collectionViewSelectAll()
                }
            )
        )

        if let trash = self as? NCTrash {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_trash_restore_selected_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "restore"),
                    action: { _ in
                        self.selectOcId.forEach(trash.restoreItem)
                        self.tapSelect()
                    }
                )
            )
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_trash_delete_selected_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "trash"),
                    action: { _ in
                        let alert = UIAlertController(title: NSLocalizedString("_trash_delete_selected_", comment: ""), message: "", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .destructive, handler: { _ in
                            self.selectOcId.forEach(trash.deleteItem)
                            self.tapSelect()
                        }))
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in }))
                        self.present(alert, animated: true, completion: nil)
                    }
                )
            )
            return presentMenu(with: actions)
        }

        //
        // OPEN IN
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_open_in_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "square.and.arrow.up"),
                action: { _ in
                    NCFunctionCenter.shared.openActivityViewController(selectOcId: self.selectOcId)
                    self.tapSelect()
                }
            )
        )

        //
        // SAVE TO PHOTO GALLERY
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_save_selected_files_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "square.and.arrow.down"),
                action: { _ in
                    self.selectOcId
                        .compactMap(NCManageDatabase.shared.getMetadataFromOcId)
                        .filter({ $0.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || $0.classFile == NCCommunicationCommon.typeClassFile.video.rawValue })
                        .forEach { metadata in
                            if let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                                NCFunctionCenter.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV)
                            } else {
                                if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                                    NCFunctionCenter.shared.saveAlbum(metadata: metadata)
                                } else {
                                    NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                                }
                            }
                        }
                    self.tapSelect()
                }
            )
        )

        //
        // COPY - MOVE
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_move_or_copy_selected_files_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "arrow.up.right.square"),
                action: { _ in
                    let meradatasSelect = self.selectOcId.compactMap(NCManageDatabase.shared.getMetadataFromOcId)
                    if !meradatasSelect.isEmpty {
                        NCFunctionCenter.shared.openSelectView(items: meradatasSelect, viewController: self)
                    }
                    self.tapSelect()
                }
            )
        )

        //
        // COPY
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_copy_file_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "doc.on.doc"),
                action: { _ in
                    self.appDelegate.pasteboardOcIds = self.selectOcId
                    NCFunctionCenter.shared.copyPasteboard()
                    self.tapSelect()
                }
            )
        )

        //
        // DELETE
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_selected_files_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "trash"),
                action: { _ in
                    let meradatasSelect = self.selectOcId.compactMap(NCManageDatabase.shared.getMetadataFromOcId)

                    let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (_: UIAlertAction) in
                        meradatasSelect.forEach({ NCOperationQueue.shared.delete(metadata: $0, onlyLocalCache: false) })
                        self.tapSelect()
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (_: UIAlertAction) in
                        meradatasSelect.forEach({ NCOperationQueue.shared.delete(metadata: $0, onlyLocalCache: true) })
                        self.tapSelect()
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (_: UIAlertAction) in })
                    self.present(alertController, animated: true, completion: nil)
                }
            )
        )

        presentMenu(with: actions)
    }
}

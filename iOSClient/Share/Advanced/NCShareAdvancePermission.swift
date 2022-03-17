//
//  NCShareAdvancePermission.swift
//  Nextcloud
//
//  Created by T-systems on 09/08/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit
import NCCommunication
import SVGKit
import CloudKit

class NCShareAdvancePermission: UITableViewController {
    var share: tableShare!
    var metadata: tableMetadata!
    var shareConfig: ShareConfig!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.shareConfig = ShareConfig(isDirectory: metadata.directory, share: share)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard tableView.tableHeaderView == nil, tableView.tableFooterView == nil else { return }
        setupHeaderView()
        setupFooterView()
    }
    @objc func cancelClicked() {
        navigationController?.popViewController(animated: true)
    }

    @objc func nextClicked() {
    }

    func setupFooterView() {
        guard let footerView = (Bundle.main.loadNibNamed("NCShareAdvancePermissionFooter", owner: self, options: nil)?.first as? NCShareAdvancePermissionFooter) else { return }
        footerView.backgroundColor = .clear
        footerView.addShadow(location: .top)

        footerView.buttonCancel.addTarget(self, action: #selector(cancelClicked), for: .touchUpInside)
        footerView.buttonCancel.setTitle(NSLocalizedString("_cancel_", comment: ""), for: .normal)
        footerView.buttonCancel.layer.cornerRadius = 10
        footerView.buttonCancel.layer.masksToBounds = true
        footerView.buttonCancel.layer.borderWidth = 1

        if NCManageDatabase.shared.getTableShare(account: share.account, idShare: share.idShare) == nil {
            footerView.buttonNext.setTitle(NSLocalizedString("_next_", comment: ""), for: .normal)
        } else {
            footerView.buttonNext.setTitle(NSLocalizedString("_apply_changes_", comment: ""), for: .normal)
        }
        footerView.buttonNext.layer.cornerRadius = 10
        footerView.buttonNext.layer.masksToBounds = true
        footerView.buttonNext.backgroundColor = NCBrandColor.shared.brand
        footerView.buttonNext.addTarget(self, action: #selector(nextClicked), for: .touchUpInside)

        footerView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 100)
        tableView.tableFooterView = footerView
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)

        footerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        footerView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        footerView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
        footerView.heightAnchor.constraint(equalToConstant: 100).isActive = true
    }

    func setupHeaderView() {
        guard let headerView = (Bundle.main.loadNibNamed("NCShareAdvancePermissionHeader", owner: self, options: nil)?.first as? NCShareAdvancePermissionHeader) else { return }
//        headerView.backgroundColor = NCBrandColor.shared.secondarySystemBackground
        if FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            headerView.fullWidthImageView.image = NCUtility.shared.getImageMetadata(metadata, for: headerView.frame.height)
            headerView.fullWidthImageView.contentMode = .scaleAspectFill
            headerView.imageView.isHidden = true
        } else {
            if metadata!.directory {
                headerView.imageView.image = UIImage(named: "folder")
            } else if !metadata.iconName.isEmpty {
                headerView.imageView.image = UIImage(named: metadata.iconName)
            } else {
                headerView.imageView.image = UIImage(named: "file")
            }
        }
        headerView.favorite.setNeedsUpdateConstraints()
        headerView.favorite.layoutIfNeeded()
        headerView.fileName.text = self.metadata?.fileNameView
        headerView.fileName.textColor = NCBrandColor.shared.label
        headerView.favorite.addTarget(self, action: #selector(favoriteClicked), for: .touchUpInside)
        if metadata.favorite {
            headerView.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite, size: 24), for: .normal)
        } else {
            headerView.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.systemGray, size: 24), for: .normal)
        }
        headerView.info.textColor = NCBrandColor.shared.secondaryLabel
        headerView.info.text = CCUtility.transformedSize(metadata.size) + ", " + CCUtility.dateDiff(metadata.date as Date)
        headerView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 200)
        tableView.tableHeaderView = headerView
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        headerView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return NSLocalizedString("_advanced_", comment: "") }
        else if section == 1 { return NSLocalizedString("_misc_", comment: "") }
        else { return nil }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return shareConfig.permissions.count }
        else if section == 1 { return shareConfig.advanced.count }
        else { return 0 }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = shareConfig.cellFor(indexPath: indexPath) else { return UITableViewCell() }
        return cell
    }

    @objc func favoriteClicked() {
        
    }
}

protocol ShareCellConfig {
    var title: String { get }
    func isOn(for share: tableShare) -> Bool
    func didChange(_ share: tableShare, to newValue: Bool)
}

protocol Permission: ShareCellConfig {
    static var forDirectory: [Self] { get }
    static var forFile: [Self] { get }
}

enum UserPermission: CaseIterable, Permission {
    func didChange(_ share: tableShare, to newValue: Bool) {
        
    }

    func isOn(for share: tableShare) -> Bool {
        switch self {
        case .reshare: return CCUtility.isPermission(toCanShare: share.permissions)
        case .edit: return CCUtility.isPermission(toCanChange: share.permissions)
        case .create: return CCUtility.isPermission(toCanCreate: share.permissions)
        case .delete: return CCUtility.isPermission(toCanDelete: share.permissions)
        }
    }

    func handleAction(for tableShare: tableShare) {
        switch self {
        case .reshare: break
        case .edit: break
        case .create: break
        case .delete: break
        }
    }

    case reshare, edit, create, delete
    static let forDirectory: [UserPermission] = UserPermission.allCases
    static let forFile: [UserPermission] = [.reshare, .edit]

    var title: String {
        switch self {
        case .reshare: return NSLocalizedString("_share_can_reshare_", comment: "")
        case .edit: return NSLocalizedString("_share_can_change_", comment: "")
        case .create: return NSLocalizedString("_share_can_create_", comment: "")
        case .delete: return NSLocalizedString("_share_can_delete_", comment: "")
        }
    }
}

enum LinkPermission: Permission {
    func didChange(_ share: tableShare, to newValue: Bool) {
        
    }

    func isOn(for share: tableShare) -> Bool {
        switch self {
        case .allowEdit: return CCUtility.isAnyPermission(toEdit: share.permissions)
        case .viewOnly: return !CCUtility.isAnyPermission(toEdit: share.permissions) && share.permissions != NCGlobal.shared.permissionCreateShare
        case .uploadEdit: return CCUtility.isAnyPermission(toEdit: share.permissions) && share.permissions != NCGlobal.shared.permissionCreateShare
        case .fileDrop: return share.permissions == NCGlobal.shared.permissionCreateShare
        }
    }

    var title: String {
        switch self {
        case .allowEdit: return NSLocalizedString("_share_can_change_", comment: "")
        case .viewOnly: return NSLocalizedString("_share_read_only_", comment: "")
        case .uploadEdit: return NSLocalizedString("_share_allow_upload_", comment: "")
        case .fileDrop: return NSLocalizedString("_share_file_drop_", comment: "")
        }
    }

    case allowEdit, viewOnly, uploadEdit, fileDrop
    static let forDirectory: [LinkPermission] = [.viewOnly, .uploadEdit, .fileDrop]
    static let forFile: [LinkPermission] = [.allowEdit]
}

enum Advanced: CaseIterable, ShareCellConfig {
    func didChange(_ share: tableShare, to newValue: Bool) {
        
    }

    func isOn(for share: tableShare) -> Bool {
        switch self {
        case .hideDownload: return share.hideDownload
        case .expirationDate: return share.expirationDate != nil
        case .password: return !share.shareWith.isEmpty
        case .note: return false
        }
    }

    var title: String {
        switch self {
        case .hideDownload: return NSLocalizedString("_share_hide_download_", comment: "")
        case .expirationDate: return NSLocalizedString("_share_expiration_date_", comment: "")
        case .password: return NSLocalizedString("_share_password_", comment: "")
        case .note: return NSLocalizedString("_share_note_recipient_", comment: "")
        }
    }

    case hideDownload, expirationDate, password, note
    static let forLink: [Advanced] = Advanced.allCases
    static let forUser: [Advanced] = [.expirationDate, .note]
}

struct ShareConfig {

    let permissions: [Permission]
    let advanced: [Advanced]
    let share: tableShare

    init(isDirectory: Bool, share: tableShare) {
        self.share = share
        let type: Permission.Type = share.shareType == 3 ? LinkPermission.self : UserPermission.self
        self.permissions = isDirectory ? type.forDirectory : type.forFile
        self.advanced = share.shareType == 3 ? Advanced.forLink : Advanced.forUser
    }

    func cellFor(indexPath: IndexPath) -> UITableViewCell? {
        let cellConfig: ShareCellConfig
        if indexPath.section == 0, indexPath.row < permissions.count {
            cellConfig = permissions[indexPath.row]
        } else if indexPath.section == 1, indexPath.row < advanced.count {
            cellConfig = advanced[indexPath.row]
        } else { return nil }
        let cell = ToggleCell(isOn: cellConfig.isOn(for: share)) { newValue in
            cellConfig.didChange(share, to: newValue)
        }
        cell.textLabel?.text = cellConfig.title
        return cell
    }
}

class ToggleCell: UITableViewCell {
    let toggle = UISwitch()

    init(isOn: Bool, didChange: @escaping (Bool) -> Void) {
        super.init(style: .default, reuseIdentifier: "toggleCell")
        toggle.frame = .zero
        toggle.isOn = isOn
        toggle.action(for: .valueChanged) { _ in
            didChange(self.toggle.isOn)
        }
        self.accessoryView = toggle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

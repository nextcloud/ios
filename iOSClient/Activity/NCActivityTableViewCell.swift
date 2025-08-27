// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import FloatingPanel
import Queuer

class NCActivityCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!

    var fileId = ""
    var indexPath = IndexPath()
}

class NCActivityTableViewCell: UITableViewCell, NCCellProtocol {
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var subjectLeadingConstraint: NSLayoutConstraint!

    private var user: String = ""
    private var index = IndexPath()

    var idActivity: Int = 0
    var activityPreviews: [tableActivityPreview] = []
    var didSelectItemEnable: Bool = true
    var viewController = NCActivity()
    let utilityFileSystem = NCUtilityFileSystem()
    var account: String!

    let utility = NCUtility()

    var indexPath: IndexPath {
        get { return index }
        set { index = newValue }
    }
    var fileAvatarImageView: UIImageView? {
        return avatar
    }
    var fileUser: String? {
        get { return user }
        set { user = newValue ?? "" }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let avatarRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAvatarImage(_:)))
        avatar.addGestureRecognizer(avatarRecognizer)
    }

    @objc func tapAvatarImage(_ sender: Any?) {
        guard let fileUser = fileUser else { return }
        viewController.showProfileMenu(userId: fileUser, session: NCSession.shared.getSession(account: account), sender: sender)
    }
}

// MARK: - Collection View

extension NCActivityTableViewCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Select not permitted
        if !didSelectItemEnable {
            return
        }
        let activityPreview = activityPreviews[indexPath.row]

        if activityPreview.view == "trashbin" {
            var responder: UIResponder? = collectionView

            while !(responder is UIViewController) {
                responder = responder?.next
                if responder == nil {
                    break
                }
            }
            if (responder as? UIViewController)!.navigationController != nil {
                if let viewController = UIStoryboard(name: "NCTrash", bundle: nil).instantiateInitialViewController() as? NCTrash {
                    if let result = NCManageDatabase.shared.getTableTrash(fileId: String(activityPreview.fileId), account: activityPreview.account) {
                        viewController.blinkFileId = result.fileId
                        viewController.filePath = result.filePath
                        (responder as? UIViewController)!.navigationController?.pushViewController(viewController, animated: true)
                    } else {
                        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_trash_file_not_found_")
                        NCContentPresenter().showError(error: error)
                    }
                }
            }
            return
        }

        if activityPreview.view == NCGlobal.shared.appName && activityPreview.mimeType != "dir" {
            guard let activitySubjectRich = NCManageDatabase.shared.getActivitySubjectRich(account: activityPreview.account, idActivity: activityPreview.idActivity, id: String(activityPreview.fileId)) else {
                return
            }
            Task {
                await NCDownloadAction.shared.viewerFile(account: account, fileId: activitySubjectRich.id, viewController: viewController)
            }
        }
    }
}

extension NCActivityTableViewCell: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let results = activityPreviews.unique { $0.fileId }
        return results.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: NCActivityCollectionViewCell = (collectionView.dequeueReusableCell(withReuseIdentifier: "collectionCell", for: indexPath) as? NCActivityCollectionViewCell)!

        cell.imageView.image = nil
        cell.indexPath = indexPath

        let activityPreview = activityPreviews[indexPath.row]
        let fileId = String(activityPreview.fileId)

        // Trashbin
        if activityPreview.view == "trashbin" {
            let source = activityPreview.source

            utility.convertSVGtoPNGWriteToUserData(svgUrlString: source, width: 100, rewrite: false, account: account, id: idActivity) { imageNamePath, id in
                if let imageNamePath = imageNamePath, id == self.idActivity, let image = UIImage(contentsOfFile: imageNamePath) {
                    cell.imageView.image = image
                } else {
                    cell.imageView.image = NCImageCache.shared.getImageFile()
                }
            }
        } else {
            if activityPreview.isMimeTypeIcon {
                let source = activityPreview.source

                utility.convertSVGtoPNGWriteToUserData(svgUrlString: source, width: 150, rewrite: false, account: account, id: idActivity) { imageNamePath, id in
                    if let imageNamePath = imageNamePath, id == self.idActivity, let image = UIImage(contentsOfFile: imageNamePath) {
                        cell.imageView.image = image
                    } else {
                        cell.imageView.image = NCImageCache.shared.getImageFile()
                    }
                }
            } else {
                if let activitySubjectRich = NCManageDatabase.shared.getActivitySubjectRich(account: activityPreview.account, idActivity: idActivity, id: fileId) {
                    let fileNamePath = NCUtilityFileSystem().createServerUrl(serverUrl: utilityFileSystem.directoryUserData, fileName: activitySubjectRich.name)

                    if FileManager.default.fileExists(atPath: fileNamePath), let image = UIImage(contentsOfFile: fileNamePath) {
                        cell.imageView.image = image
                        cell.imageView?.contentMode = .scaleAspectFill
                    } else {
                        cell.imageView?.image = utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])
                        cell.imageView?.contentMode = .scaleAspectFit
                        cell.fileId = fileId
                        if !FileManager.default.fileExists(atPath: fileNamePath) {
                            if NCNetworking.shared.downloadThumbnailActivityQueue.operations.filter({ ($0 as? NCOperationDownloadThumbnailActivity)?.fileId == fileId }).isEmpty {
                                NCNetworking.shared.downloadThumbnailActivityQueue.addOperation(NCOperationDownloadThumbnailActivity(fileId: fileId, etag: "", fileNamePreviewLocalPath: fileNamePath, account: account, collectionView: collectionView))
                            }
                        }
                    }
                }
            }
        }
        return cell
    }
}

extension NCActivityTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 50, height: 30)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
    }
}

class NCOperationDownloadThumbnailActivity: ConcurrentOperation, @unchecked Sendable {
    var collectionView: UICollectionView?
    var fileNamePreviewLocalPath: String
    var fileId: String
    var account: String
    var etag: String

    init(fileId: String, etag: String, fileNamePreviewLocalPath: String, account: String, collectionView: UICollectionView?) {
        self.fileNamePreviewLocalPath = fileNamePreviewLocalPath
        self.fileId = fileId
        self.account = account
        self.collectionView = collectionView
        self.etag = etag
    }

    override func start() {
        guard !isCancelled else { return self.finish() }
        NextcloudKit.shared.downloadPreview(fileId: fileId, etag: etag, account: account) { task in
            Task {
                let identifier = self.fileId + NCGlobal.shared.taskIdentifierDownloadPreview
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, _, _, _, responseData, error in
            if error == .success, let data = responseData?.data, let collectionView = self.collectionView {
                for case let cell as NCActivityCollectionViewCell in collectionView.visibleCells {
                    if self.fileId == cell.fileId {
                        UIView.transition(with: cell.imageView,
                                          duration: 0.75,
                                          options: .transitionCrossDissolve,
                                          animations: { cell.imageView.image = UIImage(data: data) },
                                          completion: nil)
                    }
                }
            }
            self.finish()
        }
    }
}

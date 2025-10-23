//
//  NCShareNetworking.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

import UIKit
import NextcloudKit

class NCShareNetworking: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared
    weak var delegate: NCShareNetworkingDelegate?
    var view: UIView
    var metadata: tableMetadata
    var session: NCSession.Session

    init(metadata: tableMetadata, view: UIView, delegate: NCShareNetworkingDelegate?, session: NCSession.Session) {
        self.metadata = metadata
        self.view = view
        self.delegate = delegate
        self.session = session

        super.init()
    }

    private func readDownloadLimit(account: String, token: String) async throws -> NKDownloadLimit? {
        return try await withCheckedThrowingContinuation { continuation in
            NextcloudKit.shared.getDownloadLimit(account: account, token: token) { limit, error in
                if error != .success {
                    continuation.resume(throwing: error.error)
                    return
                } else {
                    continuation.resume(returning: limit)
                }
            }
        }
    }

    func readDownloadLimits(account: String, tokens: [String]) async throws {
        for token in tokens {
            self.database.deleteDownloadLimit(byAccount: account, shareToken: token)
            if let downloadLimit = try await readDownloadLimit(account: account, token: token) {
                self.database.createDownloadLimit(account: account, count: downloadLimit.count, limit: downloadLimit.limit, token: token)
            }
        }
    }

    func readShare(showLoadingIndicator: Bool) {
        if showLoadingIndicator {
            NCActivityIndicator.shared.start(backgroundView: view)
        }
        let filenamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)
        let parameter = NKShareParameter(path: filenamePath)

        NextcloudKit.shared.readShares(parameters: parameter, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.metadata.account,
                                                                                            path: filenamePath,
                                                                                            name: "readShares")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { account, shares, _, error in
            if error == .success, let shares = shares {
                self.database.deleteTableShare(account: account, path: "/" + filenamePath)
                let home = self.utilityFileSystem.getHomeServer(session: self.session)
                self.database.addShare(account: self.metadata.account, home: home, shares: shares)

                NextcloudKit.shared.getGroupfolders(account: account) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                    name: "getGroupfolders")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                } completion: { account, results, _, error in
                    if showLoadingIndicator {
                        NCActivityIndicator.shared.stop()
                    }
                    if error == .success, let groupfolders = results {
                        self.database.addGroupfolders(account: account, groupfolders: groupfolders)
                    }

                    Task {
                        try? await self.readDownloadLimits(account: account, tokens: shares.map(\.token))

                        Task { @MainActor in
                            self.delegate?.readShareCompleted()
                        }
                    }
                }
            } else {
                if showLoadingIndicator {
                    NCActivityIndicator.shared.stop()
                }
                NCContentPresenter().showError(error: error)
                self.delegate?.readShareCompleted()
            }
        }
    }

    func createShare(_ shareable: Shareable, downloadLimit: DownloadLimitViewModel) {
        NCActivityIndicator.shared.start(backgroundView: view)
        let filenamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)
        let capabilities = NCNetworking.shared.capabilities[self.metadata.account] ?? NKCapabilities.Capabilities()

        NextcloudKit.shared.createShare(path: filenamePath,
                                        shareType: shareable.shareType,
                                        shareWith: shareable.shareWith,
                                        publicUpload: false,
                                        note: shareable.note,
                                        hideDownload: false,
                                        password: shareable.password,
                                        permissions: shareable.permissions,
                                        attributes: shareable.attributes,
                                        account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.metadata.account,
                                                                                            path: filenamePath,
                                                                                            name: "createShare")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, share, _, error in
            NCActivityIndicator.shared.stop()

            if error == .success, let share = share {
                shareable.idShare = share.idShare
                let home = self.utilityFileSystem.getHomeServer(session: self.session)
                self.database.addShare(account: self.metadata.account, home: home, shares: [share])

                if shareable.hasChanges(comparedTo: share) {
                    self.updateShare(shareable, downloadLimit: downloadLimit)
                    // Download limit update should happen implicitly on share update.
                } else {
                    if case let .limited(limit, _) = downloadLimit,
                       capabilities.fileSharingDownloadLimit,
                       shareable.shareType == NCShareCommon.shareTypeLink,
                       shareable.itemType == NCShareCommon.itemTypeFile {
                        self.setShareDownloadLimit(limit, token: share.token)
                    }
                }

                Task {
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferReloadData(serverUrl: self.metadata.serverUrl, requestData: true, status: nil)
                    }
                }
            } else {
                NCContentPresenter().showError(error: error)
            }

            self.delegate?.shareCompleted()
        }
    }

    func unShare(idShare: Int) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.deleteShare(idShare: idShare, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.metadata.account,
                                                                                            path: "_\(idShare)",
                                                                                            name: "deleteShare")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { account, _, error in
            NCActivityIndicator.shared.stop()

            if error == .success {
                self.database.deleteTableShare(account: account, idShare: idShare)
                self.delegate?.unShareCompleted()

                Task {
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferReloadData(serverUrl: self.metadata.serverUrl, requestData: true, status: nil)
                    }
                }
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    func updateShare(_ shareable: Shareable, downloadLimit: DownloadLimitViewModel) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.updateShare(idShare: shareable.idShare, password: shareable.password, expireDate: shareable.formattedDateString, permissions: shareable.permissions, note: shareable.note, label: shareable.label, hideDownload: shareable.hideDownload, attributes: shareable.attributes, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.metadata.account,
                                                                                            path: "_\(shareable.idShare)",
                                                                                            name: "updateShare")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, share, _, error in
            NCActivityIndicator.shared.stop()

            if error == .success, let share = share {
                let home = self.utilityFileSystem.getHomeServer(session: self.session)
                let capabilities = NCNetworking.shared.capabilities[self.metadata.account] ?? NKCapabilities.Capabilities()

                self.database.addShare(account: self.metadata.account, home: home, shares: [share])
                self.delegate?.readShareCompleted()

                if capabilities.fileSharingDownloadLimit,
                   shareable.shareType == NCShareCommon.shareTypeLink,
                   shareable.itemType == NCShareCommon.itemTypeFile {
                    if case let .limited(limit, _) = downloadLimit {
                        self.setShareDownloadLimit(limit, token: share.token)
                    } else {
                        self.removeShareDownloadLimit(token: share.token)
                    }
                }

                Task {
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferReloadData(serverUrl: self.metadata.serverUrl, requestData: true, status: nil)
                    }
                }
            } else {
                NCContentPresenter().showError(error: error)
                self.delegate?.updateShareWithError(idShare: shareable.idShare)
            }
        }
    }

    func getSharees(searchString: String) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.searchSharees(search: searchString, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.metadata.account,
                                                                                            path: searchString,
                                                                                            name: "searchSharees")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, sharees, _, error in
            NCActivityIndicator.shared.stop()

            if error == .success {
                self.delegate?.getSharees(sharees: sharees)
            } else {
                NCContentPresenter().showError(error: error)
                self.delegate?.getSharees(sharees: nil)
            }
        }
    }

    // MARK: - Download Limit

    ///
    /// Remove the download limit on the share, if existent.
    ///
    func removeShareDownloadLimit(token: String) {
        let capabilities = NCNetworking.shared.capabilities[self.metadata.account] ?? NKCapabilities.Capabilities()

        if !capabilities.fileSharingDownloadLimit || token.isEmpty {
            return
        }

        NCActivityIndicator.shared.start(backgroundView: view)

        NextcloudKit.shared.removeShareDownloadLimit(account: metadata.account, token: token) { error in
            NCActivityIndicator.shared.stop()

            if error == .success {
                self.delegate?.downloadLimitRemoved(by: token)
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    ///
    /// Set the download limit for the share.
    ///
    /// - Parameter limit: The new download limit to set.
    ///
    func setShareDownloadLimit(_ limit: Int, token: String) {
        let capabilities = NCNetworking.shared.capabilities[self.metadata.account] ?? NKCapabilities.Capabilities()

        if !capabilities.fileSharingDownloadLimit || token.isEmpty {
            return
        }

        NCActivityIndicator.shared.start(backgroundView: view)

        NextcloudKit.shared.setShareDownloadLimit(account: metadata.account, token: token, limit: limit) { error in
            NCActivityIndicator.shared.stop()

            if error == .success {
                self.delegate?.downloadLimitSet(to: limit, by: token)
            } else {
                self.delegate?.downloadLimitRemoved(by: token)
                NCContentPresenter().showError(error: error)
            }
        }
    }
}

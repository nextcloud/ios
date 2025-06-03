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

        NextcloudKit.shared.readShares(parameters: parameter, account: metadata.account) { account, shares, _, error in
            if error == .success, let shares = shares {
                self.database.deleteTableShare(account: account, path: "/" + filenamePath)
                let home = self.utilityFileSystem.getHomeServer(session: self.session)
                self.database.addShare(account: self.metadata.account, home: home, shares: shares)

                NextcloudKit.shared.getGroupfolders(account: account) { account, results, _, error in
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

    func createShare(_ template: Shareable, downloadLimit: DownloadLimitViewModel) {
        // NOTE: Permissions don't work for creating with file drop!
        // https://github.com/nextcloud/server/issues/17504

        NCActivityIndicator.shared.start(backgroundView: view)
        let filenamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)

        NextcloudKit.shared.createShare(path: filenamePath, shareType: template.shareType, shareWith: template.shareWith, password: template.password, note: template.note, permissions: template.permissions, attributes: template.attributes, account: metadata.account) { _, share, _, error in
            NCActivityIndicator.shared.stop()

            if error == .success, let share = share {
                template.idShare = share.idShare
                let home = self.utilityFileSystem.getHomeServer(session: self.session)
                self.database.addShare(account: self.metadata.account, home: home, shares: [share])

                if template.hasChanges(comparedTo: share) {
                    self.updateShare(template, downloadLimit: downloadLimit)
                    // Download limit update should happen implicitly on share update.
                } else {
                    if case let .limited(limit, _) = downloadLimit {
                        self.setShareDownloadLimit(limit, token: share.token)
                    }
                }

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferRequestData(serverUrl: self.metadata.serverUrl)
                }
            } else {
                NCContentPresenter().showError(error: error)
            }

            self.delegate?.shareCompleted()
        }
    }

    func unShare(idShare: Int) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.deleteShare(idShare: idShare, account: metadata.account) { account, _, error in
            NCActivityIndicator.shared.stop()

            if error == .success {
                self.database.deleteTableShare(account: account, idShare: idShare)
                self.delegate?.unShareCompleted()

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferRequestData(serverUrl: self.metadata.serverUrl)
                }
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    func updateShare(_ option: Shareable, downloadLimit: DownloadLimitViewModel) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.updateShare(idShare: option.idShare, password: option.password, expireDate: option.formattedDateString, permissions: option.permissions, note: option.note, label: option.label, hideDownload: option.hideDownload, attributes: option.attributes, account: metadata.account) { _, share, _, error in
            NCActivityIndicator.shared.stop()

            if error == .success, let share = share {
                let home = self.utilityFileSystem.getHomeServer(session: self.session)
                self.database.addShare(account: self.metadata.account, home: home, shares: [share])
                self.delegate?.readShareCompleted()

                if case let .limited(limit, _) = downloadLimit {
                    self.setShareDownloadLimit(limit, token: share.token)
                } else {
                    self.removeShareDownloadLimit(token: share.token)
                }

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferRequestData(serverUrl: self.metadata.serverUrl)
                }
            } else {
                NCContentPresenter().showError(error: error)
                self.delegate?.updateShareWithError(idShare: option.idShare)
            }
        }
    }

    func getSharees(searchString: String) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.searchSharees(search: searchString, account: metadata.account) { _, sharees, _, error in
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
        if !NCCapabilities().getCapabilities(account: metadata.account).capabilityFileSharingDownloadLimit { return }

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
        if !NCCapabilities().getCapabilities(account: metadata.account).capabilityFileSharingDownloadLimit { return }

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

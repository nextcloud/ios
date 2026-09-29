// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

extension BackgroundUploadExtension {
    /// Links up to ten fully uploaded Live Photo pairs without letting one failed pair block the others.
    /// Failed records remain in Realm so a later extension run or the host app can retry safely.
    func processPendingLivePhotos(account: String) async -> Bool {
        let livePhotos = await database.getLivePhotos(account: account, limit: 10)
        var madeProgress = false

        for livePhoto in livePhotos {
            if await linkLivePhoto(livePhoto, account: account) {
                madeProgress = true
            }

            // An authentication failure affects the whole account; avoid repeating it for the batch.
            if preferences.isBackgroundUploadSuspended(account: account) {
                break
            }
        }

        return madeProgress
    }

    /// Links both server resources and removes the pending record only after both calls succeed.
    private func linkLivePhoto(_ livePhoto: tableLivePhoto, account: String) async -> Bool {
        let videoResult = await NextcloudKit.shared.setLivephotoAsync(
            serverUrlfileNamePath: livePhoto.serverUrlFileNameVideo,
            livePhotoFile: livePhoto.fileIdImage,
            account: account
        )

        guard videoResult.error == .success else {
            return await handleLivePhotoLinkFailure(
                livePhoto,
                component: "video",
                path: livePhoto.serverUrlFileNameVideo,
                errorCode: videoResult.error.errorCode,
                account: account
            )
        }

        let imageResult = await NextcloudKit.shared.setLivephotoAsync(
            serverUrlfileNamePath: livePhoto.serverUrlFileNameImage,
            livePhotoFile: livePhoto.fileIdVideo,
            account: account
        )

        guard imageResult.error == .success else {
            return await handleLivePhotoLinkFailure(
                livePhoto,
                component: "image",
                path: livePhoto.serverUrlFileNameImage,
                errorCode: imageResult.error.errorCode,
                account: account
            )
        }

        await database.setLivePhotoFile(
            fileId: livePhoto.fileIdVideo,
            livePhotoFile: livePhoto.fileIdImage
        )
        await database.setLivePhotoFile(
            fileId: livePhoto.fileIdImage,
            livePhotoFile: livePhoto.fileIdVideo
        )
        await database.deleteLivePhoto(
            account: account,
            serverUrlFileNameNoExt: livePhoto.serverUrlFileNameNoExt
        )

        logInfo(
            "Linked Live Photo \(livePhoto.serverUrlFileNameImage) with " +
            "\(livePhoto.serverUrlFileNameVideo)"
        )
        return true
    }

    /// Removes pairs whose server resource no longer exists and retains transient failures for retry.
    /// Authentication errors suspend the account immediately to avoid repeating invalid requests.
    private func handleLivePhotoLinkFailure(
        _ livePhoto: tableLivePhoto,
        component: String,
        path: String,
        errorCode: Int,
        account: String
    ) async -> Bool {
        if errorCode == global.errorResourceNotFound {
            await database.deleteLivePhoto(
                account: account,
                serverUrlFileNameNoExt: livePhoto.serverUrlFileNameNoExt
            )
            logError("Discarded Live Photo because its \(component) resource no longer exists: \(path)")
            return true
        }

        await database.setLivePhotoError(
            account: account,
            serverUrlFileNameNoExt: livePhoto.serverUrlFileNameNoExt
        )

        if errorCode == global.errorUnauthorized {
            preferences.setBackgroundUploadSuspended(true, account: account)
            logError("Suspended background upload after a Live Photo authentication failure for account \(account)")
        }

        logError("Unable to link Live Photo \(component) \(path), error: \(errorCode)")
        return false
    }
}

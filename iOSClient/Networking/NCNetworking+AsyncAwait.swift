//
//  NCNetworking+AsyncAwait.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 30/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit
import NextcloudKit
import Alamofire

extension NCNetworking {
    func getServerStatus(serverUrl: String,
                         options: NKRequestOptions = NKRequestOptions()) async -> NextcloudKit.ServerInfoResult {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getServerStatus(serverUrl: serverUrl) { serverInfoResult in
                continuation.resume(returning: serverInfoResult)
            }
        })
    }

    func setLivephoto(serverUrlfileNamePath: String,
                      livePhotoFile: String,
                      options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath, livePhotoFile: livePhotoFile, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    func getUserProfile(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, userProfile: NKUserProfile?, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getUserProfile(options: options) { account, userProfile, data, error in
                continuation.resume(returning: (account: account, userProfile: userProfile, data: data, error: error))
            }
        })
    }

    func sendClientDiagnosticsRemoteOperation(data: Data,
                                              options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.sendClientDiagnosticsRemoteOperation(data: data, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    func getPreview(url: URL, options: NKRequestOptions = NKRequestOptions()) async -> (account: String, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getPreview(url: url, options: options) { account, data, error in
                continuation.resume(returning: (account: account, data: data, error: error))
            }
        })
    }

    func downloadPreview(fileId: String,
                         fileNamePreviewLocalPath: String,
                         fileNameIconLocalPath: String? = nil,
                         widthPreview: Int = 512,
                         heightPreview: Int = 512,
                         sizeIcon: Int = 512,
                         etag: String? = nil,
                         crop: Int = 0,
                         cropMode: String = "fill",
                         forceIcon: Int = 1,
                         mimeFallback: Int = 0,
                         options: NKRequestOptions = NKRequestOptions()) async -> (account: String, imagePreview: UIImage?, imageIcon: UIImage?, imageOriginal: UIImage?, etag: String?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.downloadPreview(fileId: fileId, fileNamePreviewLocalPath: fileNamePreviewLocalPath, fileNameIconLocalPath: fileNameIconLocalPath, widthPreview: widthPreview, heightPreview: heightPreview, sizeIcon: sizeIcon, etag: etag, crop: crop, cropMode: cropMode, forceIcon: forceIcon, mimeFallback: mimeFallback, options: options) { account, imagePreview, imageIcon, imageOriginal, etag, error in
                continuation.resume(returning: (account: account, imagePreview: imagePreview, imageIcon: imageIcon, imageOriginal: imageOriginal, etag: etag, error: error))
            }
        })
    }

    func deleteFileOrFolder(serverUrlFileName: String,
                            options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    func moveFileOrFolder(serverUrlFileNameSource: String,
                          serverUrlFileNameDestination: String,
                          overwrite: Bool,
                          options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    func copyFileOrFolder(serverUrlFileNameSource: String,
                          serverUrlFileNameDestination: String,
                          overwrite: Bool,
                          options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    func createFolder(serverUrlFileName: String,
                      options: NKRequestOptions = NKRequestOptions()) async -> (account: String, ocId: String?, date: NSDate?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, options: options) { account, ocId, date, error in
                continuation.resume(returning: (account: account, ocId: ocId, date: date, error: error))
            }
        })
    }

    func readFileOrFolder(serverUrlFileName: String,
                          depth: String,
                          showHiddenFiles: Bool = true,
                          requestBody: Data? = nil,
                          options: NKRequestOptions = NKRequestOptions()) async -> (account: String, files: [NKFile], data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: depth, showHiddenFiles: showHiddenFiles, requestBody: requestBody, options: options) { account, files, data, error in
                continuation.resume(returning: (account: account, files: files, data: data, error: error))
            }
        })
    }

    func searchMedia(path: String = "",
                     lessDate: Any,
                     greaterDate: Any,
                     elementDate: String,
                     limit: Int,
                     showHiddenFiles: Bool,
                     includeHiddenFiles: [String] = [],
                     options: NKRequestOptions = NKRequestOptions()) async -> (account: String, files: [NKFile], data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.searchMedia(path: path, lessDate: lessDate, greaterDate: greaterDate, elementDate: elementDate, limit: limit, showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles, options: options) { account, files, data, error in
                continuation.resume(returning: (account, files, data, error))
            }
        })
    }

    func markE2EEFolder(fileId: String,
                        delete: Bool,
                        options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.markE2EEFolder(fileId: fileId, delete: delete, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    func lockE2EEFolder(fileId: String,
                        e2eToken: String?,
                        e2eCounter: String?,
                        method: String,
                        options: NKRequestOptions = NKRequestOptions()) async -> (account: String, e2eToken: String?, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.lockE2EEFolder(fileId: fileId, e2eToken: e2eToken, e2eCounter: e2eCounter, method: method, options: options) { account, e2eToken, data, error in
                continuation.resume(returning: (account: account, e2eToken: e2eToken, data: data, error: error))
            }
        })
    }

    func getE2EEMetadata(fileId: String,
                         e2eToken: String?,
                         options: NKRequestOptions = NKRequestOptions()) async -> (account: String, e2eMetadata: String?, signature: String?, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken, options: options) { account, e2eMetadata, signature, data, error in
                continuation.resume(returning: (account: account, e2eMetadata: e2eMetadata, signature: signature, data: data, error: error))
            }
        })
    }

    func putE2EEMetadata(fileId: String,
                         e2eToken: String,
                         e2eMetadata: String?,
                         signature: String?,
                         method: String,
                         options: NKRequestOptions = NKRequestOptions()) async -> (account: String, metadata: String?, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: signature, method: method, options: options) { account, metadata, data, error in
                continuation.resume(returning: (account: account, metadata: metadata, data: data, error: error))
            }
        })
    }

    func getE2EECertificate(user: String? = nil,
                            options: NKRequestOptions = NKRequestOptions()) async -> (account: String, certificate: String?, certificateUser: String?, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getE2EECertificate(user: user, options: options) { account, certificate, certificateUser, data, error in
                continuation.resume(returning: (account: account, certificate: certificate, certificateUser: certificateUser, data: data, error: error))
            }
        })
    }

    func getE2EEPrivateKey(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, privateKey: String?, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getE2EEPrivateKey(options: options) { account, privateKey, data, error in
                continuation.resume(returning: (account: account, privateKey: privateKey, data: data, error: error))
            }
        })
    }

    func getE2EEPublicKey(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, publicKey: String?, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getE2EEPublicKey(options: options) { account, publicKey, data, error in
                continuation.resume(returning: (account: account, publicKey: publicKey, data: data, error: error))
            }
        })
    }

    func signE2EECertificate(certificate: String,
                             options: NKRequestOptions = NKRequestOptions()) async -> (account: String, certificate: String?, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.signE2EECertificate(certificate: certificate, options: options) { account, certificate, data, error in
                continuation.resume(returning: (account: account, certificate: certificate, data: data, error: error))
            }
        })
    }

    func storeE2EEPrivateKey(privateKey: String,
                             options: NKRequestOptions = NKRequestOptions()) async -> (account: String, privateKey: String?, data: Data?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.storeE2EEPrivateKey(privateKey: privateKey, options: options) { account, privateKey, data, error in
                continuation.resume(returning: (account: account, privateKey: privateKey, data: data, error: error))
            }
        })
    }

    func deleteE2EECertificate(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.deleteE2EECertificate(options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    func deleteE2EEPrivateKey(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.deleteE2EEPrivateKey(options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }
}

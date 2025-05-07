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
            NextcloudKit.shared.getServerStatus(serverUrl: serverUrl) { _, serverInfoResult in
                continuation.resume(returning: serverInfoResult)
            }
        })
    }

    func setLivephoto(serverUrlfileNamePath: String,
                      livePhotoFile: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath, livePhotoFile: livePhotoFile, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func getUserMetadata(account: String,
                         userId: String,
                         options: NKRequestOptions = NKRequestOptions()) async -> (account: String, userProfile: NKUserProfile?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getUserMetadata(account: account, userId: userId) { account, userProfile, responseData, error in
                continuation.resume(returning: (account: account, userProfile: userProfile, responseData: responseData, error: error))
            }
        })
    }

    func sendClientDiagnosticsRemoteOperation(data: Data,
                                              account: String,
                                              options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.sendClientDiagnosticsRemoteOperation(data: data, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func downloadPreview(url: URL,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.downloadPreview(url: url, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func downloadPreview(fileId: String,
                         etag: String? = nil,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions()) async -> (account: String, width: Int, height: Int, etag: String?, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.downloadPreview(fileId: fileId, etag: etag, account: account, options: options) { account, width, height, etag, responseData, error in
                continuation.resume(returning: (account: account, width: width, height: height, etag: etag, responseData: responseData, error: error))
            }
        })
    }

    func deleteFileOrFolder(serverUrlFileName: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func moveFileOrFolder(serverUrlFileNameSource: String,
                          serverUrlFileNameDestination: String,
                          overwrite: Bool,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func copyFileOrFolder(serverUrlFileNameSource: String,
                          serverUrlFileNameDestination: String,
                          overwrite: Bool,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    @discardableResult
    func createFolder(serverUrlFileName: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions()) async -> (account: String, ocId: String?, date: Date?, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, account: account, options: options) { account, ocId, date, responseData, error in
                continuation.resume(returning: (account: account, ocId: ocId, date: date, responseData: responseData, error: error))
            }
        })
    }

    func setFavorite(fileName: String,
                     favorite: Bool,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions()) async -> NKError {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite, account: account) { _, _, error in
                continuation.resume(returning: error)
            }
        })
    }

    func readFileOrFolder(serverUrlFileName: String,
                          depth: String,
                          showHiddenFiles: Bool = true,
                          requestBody: Data? = nil,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions()) async -> (account: String, files: [NKFile]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: depth, showHiddenFiles: showHiddenFiles, requestBody: requestBody, account: account, options: options) { account, files, responseData, error in
                continuation.resume(returning: (account: account, files: files, responseData: responseData, error: error))
            }
        })
    }

    func searchMedia(path: String = "",
                     lessDate: Any,
                     greaterDate: Any,
                     elementDate: String,
                     limit: Int,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions()) async -> (account: String, files: [NKFile]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.searchMedia(path: path, lessDate: lessDate, greaterDate: greaterDate, elementDate: elementDate, limit: limit, account: account, options: options) { account, files, responseData, error in
                continuation.resume(returning: (account, files, responseData, error))
            }
        })
    }

    func markE2EEFolder(fileId: String,
                        delete: Bool,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.markE2EEFolder(fileId: fileId, delete: delete, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func lockE2EEFolder(fileId: String,
                        e2eToken: String?,
                        e2eCounter: String?,
                        method: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions()) async -> (account: String, e2eToken: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.lockE2EEFolder(fileId: fileId, e2eToken: e2eToken, e2eCounter: e2eCounter, method: method, account: account, options: options) { account, e2eToken, responseData, error in
                continuation.resume(returning: (account: account, e2eToken: e2eToken, responseData: responseData, error: error))
            }
        })
    }

    func getE2EEMetadata(fileId: String,
                         e2eToken: String?,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions()) async -> (account: String, e2eMetadata: String?, signature: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { account, e2eMetadata, signature, responseData, error in
                continuation.resume(returning: (account: account, e2eMetadata: e2eMetadata, signature: signature, responseData: responseData, error: error))
            }
        })
    }

    func putE2EEMetadata(fileId: String,
                         e2eToken: String,
                         e2eMetadata: String?,
                         signature: String?,
                         method: String,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions()) async -> (account: String, metadata: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: signature, method: method, account: account, options: options) { account, metadata, responseData, error in
                continuation.resume(returning: (account: account, metadata: metadata, responseData: responseData, error: error))
            }
        })
    }

    func getE2EECertificate(user: String? = nil,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions()) async -> (account: String, certificate: String?, certificateUser: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getE2EECertificate(user: user, account: account, options: options) { account, certificate, certificateUser, responseData, error in
                continuation.resume(returning: (account: account, certificate: certificate, certificateUser: certificateUser, responseData: responseData, error: error))
            }
        })
    }

    func getE2EEPrivateKey(account: String,
                           options: NKRequestOptions = NKRequestOptions()) async -> (account: String, privateKey: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getE2EEPrivateKey(account: account, options: options) { account, privateKey, responseData, error in
                continuation.resume(returning: (account: account, privateKey: privateKey, responseData: responseData, error: error))
            }
        })
    }

    func getE2EEPublicKey(account: String,
                          options: NKRequestOptions = NKRequestOptions()) async -> (account: String, publicKey: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getE2EEPublicKey(account: account, options: options) { account, publicKey, responseData, error in
                continuation.resume(returning: (account: account, publicKey: publicKey, responseData: responseData, error: error))
            }
        })
    }

    func signE2EECertificate(certificate: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions()) async -> (account: String, certificate: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.signE2EECertificate(certificate: certificate, account: account, options: options) { account, certificate, responseData, error in
                continuation.resume(returning: (account: account, certificate: certificate, responseData: responseData, error: error))
            }
        })
    }

    func storeE2EEPrivateKey(privateKey: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions()) async -> (account: String, privateKey: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.storeE2EEPrivateKey(privateKey: privateKey, account: account, options: options) { account, privateKey, responseData, error in
                continuation.resume(returning: (account: account, privateKey: privateKey, responseData: responseData, error: error))
            }
        })
    }

    func deleteE2EECertificate(account: String,
                               options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.deleteE2EECertificate(account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func deleteE2EEPrivateKey(account: String,
                              options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data?>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.deleteE2EEPrivateKey(account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func getRecommendedFiles(account: String,
                             options: NKRequestOptions = NKRequestOptions()) async -> (account: String, recommendations: [NKRecommendation]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getRecommendedFiles(account: account, options: options) { account, recommendations, responseData, error in
            continuation.resume(returning: (account: account, recommendations: recommendations, responseData: responseData, error: error))
            }
        })
    }
}

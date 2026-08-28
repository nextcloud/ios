import ExtensionFoundation
import OSLog
import Photos
import UniformTypeIdentifiers
import NextcloudKit

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {
    internal let global = NCGlobal.shared
    internal let database = NCManageDatabase.shared
    internal let utilityFileSystem = NCUtilityFileSystem()
    internal let nkComm = NextcloudKit.shared.nkCommonInstance

    private static let logger = Logger(
        subsystem: "it.twsweb.Nextcloud.BackgroundUploadExtension",
        category: "TEST"
    )

    private static var processCount = 0

    required init() {
        Self.logger.error("""
        BGUPLOAD INIT
        Bundle: \(Bundle.main.bundleIdentifier ?? "nil")
        Time: \(Date().formatted())
        """)
    }

    func processJobs() async -> PHBackgroundResourceUploadProcessingResult {
        nkLog(
            tag: global.logTagBackgroundUpload,
            message: "processJobs begin"
        )

        do {
            var madeProgress = false

            if try await retryUploadJobs() {
                madeProgress = true
            }

            if try await acknowledgeUploadJobs() {
                madeProgress = true
            }

            if try await createUploadJobs() {
                madeProgress = true
            }

            let result: PHBackgroundResourceUploadProcessingResult =
                madeProgress ? .processing : .completed

            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "processJobs end, madeProgress: \(madeProgress)"
            )

            return result

        } catch let error as NSError
            where error.domain == PHPhotosErrorDomain &&
                  error.code == PHPhotosError.limitExceeded.rawValue {

            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "Job limit reached"
            )

            return .processing

        } catch {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "processJobs error: \(error)"
            )

            return .failure
        }
    }

    func willTerminate() async {
        Self.logger.error("""
        BGUPLOAD willTerminate()
        Time: \(Date().formatted())
        """)
    }

    private func buildDestination(
        metadata: tableMetadata,
        asset: PHAsset
    ) -> URLRequest? {

        guard let url = metadata.serverUrlFileName.encodedToUrl as? URL else {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "Invalid destination URL: \(metadata.serverUrlFileName)"
            )
            return nil
        }

        guard let nkSession = NextcloudKit.shared
            .nkCommonInstance
            .nksessions
            .session(forAccount: metadata.account)
        else {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "Session not found for account: \(metadata.account)"
            )
            return nil
        }

        let loginString = "\(nkSession.user):\(nkSession.password)"

        guard let loginData = loginString.data(using: .utf8) else {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "Unable to encode credentials for account: \(metadata.account)"
            )
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        request.setValue(
            nkSession.userAgent,
            forHTTPHeaderField: "User-Agent"
        )

        request.setValue(
            "Basic \(loginData.base64EncodedString())",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/octet-stream",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "1",
            forHTTPHeaderField: "X-NC-WebDAV-Auto-Mkcol"
        )

        if let creationDate = asset.creationDate,
           creationDate.timeIntervalSince1970 > 0 {
            request.setValue(
                "\(creationDate.timeIntervalSince1970)",
                forHTTPHeaderField: "X-OC-CTime"
            )
        }

        if let modificationDate = asset.modificationDate,
           modificationDate.timeIntervalSince1970 > 0 {
            request.setValue(
                "\(modificationDate.timeIntervalSince1970)",
                forHTTPHeaderField: "X-OC-MTime"
            )
        }

        nkLog(
            tag: global.logTagBackgroundUpload,
            message: "Destination created for \(metadata.fileName) -> \(metadata.serverUrlFileName)"
        )

        return request
    }

    private func createUploadJobs() async throws -> Bool {
        let processingJobs = PHAssetResourceUploadJob.fetchJobs(
            action: .process,
            options: nil
        )

        let acknowledgeJobs = PHAssetResourceUploadJob.fetchJobs(
            action: .acknowledge,
            options: nil
        )

        let jobsInUse = processingJobs.count + acknowledgeJobs.count
        let availableJobs = max(
            0,
            PHAssetResourceUploadJob.jobLimit - jobsInUse
        )

        guard availableJobs > 0 else {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "No available background upload job slots"
            )
            return false
        }

        let predicate = NSPredicate(
            format: """
            status == %d AND \
            backgroundUploadJobIdentifier == %@
            """,
            global.metadataStatusWaitUpload,
            "pending"
        )

        guard let metadatas = await database.getMetadatasAsync(
            predicate: predicate,
            sortedByKeyPath: "sessionDate",
            ascending: true,
            limit: availableJobs
        ),
        !metadatas.isEmpty else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        for metadata in metadatas {
            let assets = PHAsset.fetchAssets(
                withLocalIdentifiers: [metadata.assetLocalIdentifier],
                options: nil
            )

            guard let asset = assets.firstObject else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: """
                    Asset not found: \(metadata.assetLocalIdentifier), \
                    file: \(metadata.fileName)
                    """
                )
                continue
            }

            guard let resource = uploadResource(
                for: asset,
                metadata: metadata
            ) else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: """
                    Upload resource not found for asset \
                    \(metadata.assetLocalIdentifier)
                    """
                )
                continue
            }

            guard let destination = buildDestination(
                metadata: metadata,
                asset: asset
            ) else {
                continue
            }

            var jobIdentifier: String?

            try library.performChangesAndWait {
                let request =
                    PHAssetResourceUploadJobChangeRequest
                        .creationRequestForJob(
                            destination: destination,
                            resource: resource
                        )

                jobIdentifier =
                    request
                        .placeholderForCreatedAssetResourceUploadJob?
                        .localIdentifier
            }

            guard let jobIdentifier, !jobIdentifier.isEmpty else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Created job has no local identifier"
                )
                continue
            }

            metadata.backgroundUploadJobIdentifier = jobIdentifier
            metadata.status = global.metadataStatusUploading
            metadata.sessionDate = Date()
            metadata.sessionError = ""
            metadata.errorCode = 0

            await database.replaceMetadataAsync(
                ocId: metadata.ocId,
                metadata: metadata
            )

            madeProgress = true

            nkLog(
                tag: global.logTagBackgroundUpload,
                message: """
                Created background upload job \(jobIdentifier), \
                file: \(metadata.fileName), \
                resource: \(resource.filename ?? "<unknown>")
                """
            )
        }

        return madeProgress
    }

    private func acknowledgeUploadJobs() async throws -> Bool {
        let jobs = PHAssetResourceUploadJob.fetchJobs(
            action: .acknowledge,
            options: nil
        )

        guard jobs.count > 0 else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        for index in 0..<jobs.count {
            let job = jobs.object(at: index)
            let jobIdentifier = job.localIdentifier

            guard let metadata = await database.getMetadataAsync(
                predicate: NSPredicate(
                    format: "backgroundUploadJobIdentifier == %@",
                    jobIdentifier
                )
            ) else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Metadata not found for job \(jobIdentifier)"
                )

                // Non facciamo acknowledge: il risultato rimane recuperabile.
                continue
            }

            switch job.state {
            case .succeeded:
                guard await processUploadSuccess(
                    metadata: metadata,
                    job: job
                ) else {
                    continue
                }

            case .failed:
                await updateMetadataForUploadFailure(
                    metadata: metadata,
                    job: job
                )

            default:
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Unexpected state \(job.state.rawValue) for job \(jobIdentifier)"
                )
                continue
            }

            try library.performChangesAndWait {
                guard let request = PHAssetResourceUploadJobChangeRequest(
                    for: job
                ) else {
                    return
                }

                request.acknowledge()
            }

            madeProgress = true

            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "Acknowledged job \(jobIdentifier), state: \(job.state.rawValue)"
            )
        }

        return madeProgress
    }

    private func updateMetadataForUploadFailure(
        metadata: tableMetadata,
        job: PHAssetResourceUploadJob
    ) async {
        let error = job.error.map { $0 as NSError }

        // Non cancellare backgroundUploadJobIdentifier:
        // impedisce al vecchio uploader di prendere questo metadata.
        metadata.session = ""
        metadata.sessionTaskIdentifier = 0
        metadata.sessionDate = Date()
        metadata.sessionError =
            error?.localizedDescription ?? "Background upload failed"
        metadata.errorCode =
            error?.code ?? NSURLErrorUnknown
        metadata.status = global.metadataStatusUploadError

        await database.replaceMetadataAsync(
            ocId: metadata.ocId,
            metadata: metadata
        )

        nkLog(
            tag: global.logTagBackgroundUpload,
            message: """
            Background upload failed for \(metadata.fileName), \
            job: \(job.localIdentifier), \
            error: \(metadata.errorCode) \(metadata.sessionError)
            """
        )
    }

    private func retryUploadJobs() async throws -> Bool {
        let jobs = PHAssetResourceUploadJob.fetchJobs(
            action: .retry,
            options: nil
        )

        guard jobs.count > 0 else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        for index in 0..<jobs.count {
            let job = jobs.object(at: index)
            let jobIdentifier = job.localIdentifier

            guard let metadata = await database.getMetadataAsync(
                predicate: NSPredicate(
                    format: "backgroundUploadJobIdentifier == %@",
                    jobIdentifier
                )
            ) else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Retry metadata not found for job \(jobIdentifier)"
                )
                continue
            }

            let assets = PHAsset.fetchAssets(
                withLocalIdentifiers: [metadata.assetLocalIdentifier],
                options: nil
            )

            guard let asset = assets.firstObject else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: """
                    Retry asset not found for job \(jobIdentifier), \
                    asset: \(metadata.assetLocalIdentifier)
                    """
                )
                continue
            }

            guard let destination = buildDestination(
                metadata: metadata,
                asset: asset
            ) else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Unable to rebuild destination for job \(jobIdentifier)"
                )
                continue
            }

            var retryRequested = false

            try library.performChangesAndWait {
                guard let request = PHAssetResourceUploadJobChangeRequest(
                    for: job
                ) else {
                    return
                }

                request.retry(destination: destination)
                retryRequested = true
            }

            guard retryRequested else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Unable to create retry request for job \(jobIdentifier)"
                )
                continue
            }

            metadata.sessionDate = Date()
            metadata.sessionError = ""
            metadata.errorCode = 0
            metadata.status = global.metadataStatusUploading

            // Manteniamo lo stesso job identifier.
            await database.replaceMetadataAsync(
                ocId: metadata.ocId,
                metadata: metadata
            )

            madeProgress = true

            nkLog(
                tag: global.logTagBackgroundUpload,
                message: """
                Retry requested for \(metadata.fileName), \
                job: \(jobIdentifier)
                """
            )
        }

        return madeProgress
    }

    private func uploadResource(
        for asset: PHAsset,
        metadata: tableMetadata
    ) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        // Prima prova a trovare la risorsa con lo stesso nome.
        if let resource = resources.first(where: {
            $0.filename?.caseInsensitiveCompare(metadata.fileName) ==
                .orderedSame
        }) {
            return resource
        }

        // Altrimenti seleziona la risorsa principale.
        switch asset.mediaType {
        case .image:
            return resources.first(where: {
                $0.type == .fullSizePhoto
            }) ?? resources.first(where: {
                $0.type == .photo
            })

        case .video:
            return resources.first(where: {
                $0.type == .fullSizeVideo
            }) ?? resources.first(where: {
                $0.type == .video
            })

        default:
            return nil
        }
    }

    private func processUploadSuccess(
        metadata: tableMetadata,
        job: PHAssetResourceUploadJob
    ) async -> Bool {
        let headers = job.responseHeaderFields ?? [:]

        guard let ocId = headers["oc-fileid"],
              !ocId.isEmpty else {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: """
                Successful job without oc-fileid: \
                \(job.localIdentifier)
                """
            )
            return false
        }

        let etag = nkComm.normalizedETag(
            headers["oc-etag"]
        )

        let date = headers["date"]?.parsedDate(
            using: "EEE, dd MMM y HH:mm:ss zzz"
        )

        let ownerId = headers["x-nc-ownerid"]
        let permissions = headers["x-nc-permissions"]

        metadata.backgroundUploadJobIdentifier = ""
        metadata.uploadDate = (date as? NSDate) ?? NSDate()
        metadata.etag = etag ?? ""
        metadata.ocId = ocId

        if let fileId = NCUtility().ocIdToFileId(ocId: ocId) {
            metadata.fileId = fileId
        }

        if let ownerId, !ownerId.isEmpty {
           metadata.ownerId = ownerId
           if let ownerDisplayName = await NCManageDatabase.shared.getOwnerDisplayName(account: metadata.account, ownerId: ownerId) {
               metadata.ownerDisplayName = ownerDisplayName
           }
       }

       if let permissions, !permissions.isEmpty {
           metadata.permissions = permissions
       }

        metadata.chunk = 0
        metadata.sceneIdentifier = nil
        metadata.session = ""
        metadata.sessionError = ""
        metadata.sessionDate = nil
        metadata.sessionTaskIdentifier = 0
        metadata.status = NCGlobal.shared.metadataStatusNormal

        await NCManageDatabase.shared.replaceMetadataAsync(ocId: metadata.ocIdTransfer, metadata: metadata)

        return true
    }
}

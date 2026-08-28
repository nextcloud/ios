import ExtensionFoundation
import OSLog
import Photos
import UniformTypeIdentifiers
import NextcloudKit
import RealmSwift

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {
    private let global = NCGlobal.shared

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

        Self.logger.error("BGUPLOAD processJobs()")

        let library = PHPhotoLibrary.shared()

        let acknowledgeJobs = PHAssetResourceUploadJob.fetchJobs(
            action: .acknowledge,
            options: nil
        )

        Self.logger.error(
            "BGUPLOAD acknowledge jobs=\(acknowledgeJobs.count)"
        )

        if acknowledgeJobs.count > 0 {
            do {
                for index in 0..<acknowledgeJobs.count {
                    let job = acknowledgeJobs.object(at: index)

                    try library.performChangesAndWait {
                        guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else {
                            return
                        }

                        request.acknowledge()
                    }

                    let filename = job.resource.filename ?? "<nil>"

                    Self.logger.error(
                        "BGUPLOAD acknowledged \(filename, privacy: .public)"
                    )
                }

                return .completed
            } catch {
                Self.logger.error(
                    "BGUPLOAD acknowledge failed: \(error.localizedDescription, privacy: .public)"
                )

                return .failure
            }
        }

        let retryJobs = PHAssetResourceUploadJob.fetchJobs(
            action: .retry,
            options: nil
        )

        Self.logger.error(
            "BGUPLOAD retry jobs=\(retryJobs.count)"
        )

        // PER ORA non facciamo retry.
        // Non creiamo neppure nuovi job.
        if retryJobs.count > 0 {
            Self.logger.error("BGUPLOAD retry job pending - no new job created")
            return .completed
        }

        Self.logger.error("BGUPLOAD no pending jobs")

        return .completed
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
}

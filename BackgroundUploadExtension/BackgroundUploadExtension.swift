import ExtensionFoundation
import OSLog
import Photos
import UniformTypeIdentifiers

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {

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
}

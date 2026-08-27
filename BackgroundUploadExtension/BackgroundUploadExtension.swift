import ExtensionFoundation
import OSLog
import Photos

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {
    private let logger = Logger(
        subsystem: "it.twsweb.Nextcloud",
        category: "BackgroundUpload"
    )

    required init() {
        logger.info("Initialized")
    }

    func processJobs() async -> PHBackgroundResourceUploadProcessingResult {
        logger.info("processJobs() called")

        return .completed
    }

    func willTerminate() async {
        logger.info("willTerminate() called")
    }
}

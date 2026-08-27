import ExtensionFoundation
import OSLog
import Photos

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {

    private static let logger = Logger(
        subsystem: "it.twsweb.Nextcloud.BackgroundUploadExtension",
        category: "TEST"
    )

    required init() {
        Self.logger.error("🔥🔥🔥 BGUPLOAD INIT 🔥🔥🔥")
    }

    func processJobs() async -> PHBackgroundResourceUploadProcessingResult {
        Self.logger.error("🔥🔥🔥 BGUPLOAD processJobs() 🔥🔥🔥")

        return .completed
    }

    func willTerminate() async {
        Self.logger.error("🔥🔥🔥 BGUPLOAD willTerminate() 🔥🔥🔥")
    }
}

import ExtensionFoundation
import OSLog
import Photos

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {

    private static let logger = Logger(
        subsystem: "it.twsweb.Nextcloud.BackgroundUploadExtension",
        category: "TEST"
    )

    private static var processCount = 0

    required init() {
        Self.logger.error("""
        🔥🔥🔥 BGUPLOAD INIT 🔥🔥🔥
        Bundle: \(Bundle.main.bundleIdentifier ?? "nil")
        Time: \(Date().formatted())
        """)
    }

    func processJobs() async -> PHBackgroundResourceUploadProcessingResult {
        Self.processCount += 1

        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.fetchLimit = 1

        let assets = PHAsset.fetchAssets(with: .image, options: options)

        Self.logger.error("""
        🔥 BGUPLOAD processJobs()

        Invocation : \(Self.processCount)
        Images     : \(assets.count)
        """)

        if let asset = assets.firstObject {
            Self.logger.error("""
            Latest asset:
            id   : \(asset.localIdentifier, privacy: .public)
            date : \(String(describing: asset.creationDate), privacy: .public)
            """)
        }

        return .completed
    }

    func willTerminate() async {
        Self.logger.error("""
        🔥🔥🔥 BGUPLOAD willTerminate() 🔥🔥🔥
        Time: \(Date().formatted())
        """)
    }
}

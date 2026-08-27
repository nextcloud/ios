import Photos
import ExtensionFoundation

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {

    required init() {
        print("[BGUPLOAD] init")
    }

    func processJobs() async -> PHBackgroundResourceUploadProcessingResult {
        print("[BGUPLOAD] processJobs()")

        return .completed
    }

    func willTerminate() async {
        print("[BGUPLOAD] willTerminate()")
    }
}

// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import RealmSwift
import NextcloudKit

struct MigrationMultiDomains: View {
    let onCompleted: () -> Void

    @State private var progressText: String = "Preparing migration..."
    @State private var isMigrating: Bool = true

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "externaldrive.fill.badge.arrow.down")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)

            Text(progressText)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .padding()

            Spacer()
        }
        .task {
            await startMigration()
        }
    }

    private func startMigration() async {
        do {
            progressText = "Scanning files..."

            let ocIds = await getAllSubdirectoriesUnderFileProviderStorage()

            progressText = "Moving items to correct domain..."
            await performMigrationLogic(ocIds: ocIds)

            progressText = "Finishing up..."
            try await Task.sleep(nanoseconds: 500_000_000)
        } catch {
            progressText = "Migration failed: \(error.localizedDescription)"
        }

        isMigrating = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onCompleted()
        }
    }

    /// Asynchronously retrieves all subdirectories under the File Provider Storage base directory.
    ///
    /// - Returns: An array of relative subdirectory paths as `String`.
    private func getAllSubdirectoriesUnderFileProviderStorage() async -> [String] {
        let fileManager = FileManager.default
        let basePath = NCUtilityFileSystem().getDirectoryProviderStorage()
        guard !basePath.isEmpty else {
            return []
        }

        let baseURL = URL(fileURLWithPath: basePath)
        var directories: [String] = []

        do {
            let contents = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    // Relative path
                    let relativePath = url.path.replacingOccurrences(of: baseURL.path + "/", with: "")
                    directories.append(relativePath)
                }
            }
        } catch {
            print("Error while enumerating subdirectories: \(error)")
        }

        return directories
    }

    private func performMigrationLogic(ocIds: [String]) async {
        let allMetadatas = await NCManageDatabase.shared.getAllTableMetadataAsync()
        let fileManager = FileManager.default
        let utilityFileSystem = NCUtilityFileSystem()
        let sourceURL = URL(fileURLWithPath: NCUtilityFileSystem().getDirectoryProviderStorage())

        for ocId in ocIds {
            guard let metadata = allMetadatas.first(where: { $0.ocId == ocId }) else {
                print("Metadata not found for ocId: \(ocId)")
                continue
            }
            let domainPath = utilityFileSystem.getDocumentStorage(userId: metadata.userId, urlBase: metadata.urlBase)
            let documentStorageURL = URL(fileURLWithPath: domainPath)

            let destinationPath = documentStorageURL.appendingPathComponent(ocId)
            let sourcePath = sourceURL.appendingPathComponent(ocId)

            if fileManager.fileExists(atPath: sourcePath.path) {
            do {
                if fileManager.fileExists(atPath: destinationPath.path) {
                    try fileManager.removeItem(at: destinationPath)
                }
                try fileManager.moveItem(at: sourcePath, to: destinationPath)
                    print("Moved \(ocId)")
                } catch {
                    print("Error moving \(ocId): \(error)")
                }
            } else {
                print("Source path does not exist: \(sourceURL.path)")
            }
        }
    }
}

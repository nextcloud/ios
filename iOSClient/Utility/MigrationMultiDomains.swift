// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import RealmSwift
import NextcloudKit

/// A modal SwiftUI view responsible for migrating existing folders under File Provider Storage
/// to the appropriate domain subdirectories. This is used when transitioning to multi-domain support.
struct MigrationMultiDomains: View {
    let onCompleted: () -> Void

    @State private var progressText: String = NSLocalizedString("_preparing_migration_", comment: "")
    @State private var isMigrating: Bool = true
    @State private var progress: Double = 0.0

    var body: some View {
        ZStack {
            Color(NCBrandColor.shared.customer)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "externaldrive.fill.badge.icloud")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)

                Text(progressText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.white)

                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 240)
                    .padding(.bottom, 4)

                Text(String(format: "%.0f%%", progress * 100))
                    .font(.subheadline)
                    .foregroundColor(.white)

                Spacer()
            }
            .task {
                await startMigration()
            }
        }
    }

    /// Executes the migration pipeline: scan directories, move them, and finalize.
    /// 
    private func startMigration() async {
        do {
            progressText = NSLocalizedString("_scanning_files_", comment: "")

            //let ocIds = await getAllSubdirectoriesUnderFileProviderStorage()

            progressText = NSLocalizedString("_moving_items_to_domain_", comment: "")
            //await performMigrationLogic(ocIds: ocIds)

            progressText = NSLocalizedString("_finishing_up_", comment: "")
            try await Task.sleep(nanoseconds: 500_000_000)
        } catch {
            print("Migration failed: \(error.localizedDescription)")
        }

        isMigrating = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onCompleted()
        }
    }
}

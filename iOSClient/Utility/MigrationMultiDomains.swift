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
            try await Task.sleep(nanoseconds: 1_000_000_000) // fake delay

            progressText = "Moving items to correct domain..."
            try await performMigrationLogic() // 🔁 tua funzione reale

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

    private func performMigrationLogic() async throws {
        // 👉 Qui metti il tuo codice di migrazione file
        // per ogni file nel DB, spostalo nel path corretto del dominio
    }
}

// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import RealmSwift

/// A modal SwiftUI view responsible for maintenance database
struct Maintenance: View {
    let onCompleted: () -> Void

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

                Text("Ottimizzazione in corso...")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.white)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding(.top, 16)

                Spacer()
            }
            .task {
                await startMaintenance()
            }
        }
    }

    /// Executes the maintenance.
    ///
    private func startMaintenance() async {
        do {


            try await Task.sleep(nanoseconds: 500_000_000)
        } catch {
            print("Migration failed: \(error.localizedDescription)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onCompleted()
        }
    }
}

// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCFocusedAutoUploadIntroView: View {
    @Environment(\.dismiss) private var dismiss

    let onEnable: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(NSLocalizedString("_focused_auto_upload_", comment: ""))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(.primary)
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("_close_", comment: ""))

                    Spacer()
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            Spacer(minLength: 90)

            VStack(spacing: 24) {
                Text(NSLocalizedString("_focused_auto_upload_intro_heading_", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("_focused_auto_upload_intro_message_", comment: ""))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 22) {
                    guidanceRow(systemImage: "wifi", textKey: "_focused_auto_upload_wifi_")
                    guidanceRow(systemImage: "battery.100", textKey: "_focused_auto_upload_charger_")
                    guidanceRow(systemImage: "arrow.down.right.and.arrow.up.left", textKey: "_focused_auto_upload_do_not_exit_")
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 36)

            Spacer(minLength: 80)

            Button {
                onEnable()
            } label: {
                Text(NSLocalizedString("_enable_focused_auto_upload_", comment: ""))
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(
                Capsule()
                    .fill(Color(UIColor.darkGray))
            )
            .padding(.horizontal, 38)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    private func guidanceRow(systemImage: String, textKey: String) -> some View {
        HStack(spacing: 16) {
            guidanceIcon(systemImage: systemImage)

            Text(NSLocalizedString(textKey, comment: ""))
                .font(.title3)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func guidanceIcon(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 28, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: 34)
    }
}

#Preview {
    NCFocusedAutoUploadIntroView(onEnable: {})
}

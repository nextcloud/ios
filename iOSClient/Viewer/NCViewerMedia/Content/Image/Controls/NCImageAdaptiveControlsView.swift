// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

/// Image-only lower content. Actions and the fixed thumbnail area belong to the shared adaptive panel.
struct NCImageAdaptiveControlsView: View {
    let metadata: tableMetadata
    let exif: ExifData?
    let detailView: NCMediaViewerDetailView?
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let navigationHeight = min(max(0, geometry.size.height - 5), max(44, geometry.size.height * 0.18))
            let informationHeight = max(0, geometry.size.height - navigationHeight - 5)
            VStack(spacing: 5) {
                NCMediaViewerDetailView(metadata: detailView?.metadata ?? metadata, exif: availableExif, showsOnlyAvailableData: true)
                    .frame(height: informationHeight)
                    .background(controlSurface, in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.10), lineWidth: 0.5))

                // Both islands depend only on available space, never on Info visibility or metadata content.
                pageActions
                    .frame(height: navigationHeight)
                    .layoutPriority(1)
            }
        }
        .foregroundStyle(.white)
        .fontWeight(.bold)
        .tint(.white)
        .environment(\.colorScheme, .dark)
    }

    private var pageActions: some View {
        HStack(spacing: 5) {
            pageButton(systemName: "chevron.left", title: "_previous_media_", isEnabled: canGoPrevious, action: onPrevious)
            pageButton(systemName: "chevron.right", title: "_next_media_", isEnabled: canGoNext, action: onNext)
        }
    }

    private func pageButton(systemName: String, title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .bold))
                Text(NSLocalizedString(title, comment: ""))
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(controlSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var controlSurface: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.19, green: 0.22, blue: 0.28), Color(red: 0.11, green: 0.13, blue: 0.17)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var availableExif: ExifData {
        var data = detailView?.exif ?? exif ?? ExifData()
        let source = detailView?.metadata ?? metadata
        if data.width == nil, source.width > 0 { data.width = source.width }
        if data.height == nil, source.height > 0 { data.height = source.height }
        if data.latitude == nil, data.longitude == nil, source.latitude != 0, source.longitude != 0 {
            data.latitude = source.latitude
            data.longitude = source.longitude
        }
        return data
    }

}

#if DEBUG
#Preview("Adaptive Image - Available Data") {
    NCImageAdaptiveControlsView.previewView(isShowingInformation: false)
}

#Preview("Adaptive Image - Information") {
    NCImageAdaptiveControlsView.previewView(isShowingInformation: true)
}

private extension NCImageAdaptiveControlsView {
    static func previewView(isShowingInformation: Bool) -> some View {
        let metadata = tableMetadata()
        metadata.ocId = "adaptive-image-preview"
        metadata.fileName = "Waterfall.jpg"
        metadata.fileNameView = metadata.fileName
        metadata.classFile = NKTypeClassFile.image.rawValue
        metadata.size = 1_400_000
        metadata.width = 3000
        metadata.height = 2002
        var exif = ExifData()
        exif.make = "Nikon"
        exif.model = "Nikon D800E"
        exif.lensModel = "16 mm"
        exif.iso = 200
        exif.lensLength = 16
        exif.apertureValue = 10
        exif.date = Date(timeIntervalSince1970: 1_344_469_000)

        return NCImageAdaptiveControlsView(
            metadata: metadata,
            exif: isShowingInformation ? exif : nil,
            detailView: isShowingInformation ? NCMediaViewerDetailView(metadata: metadata, exif: exif) : nil,
            canGoPrevious: true,
            canGoNext: true,
            onPrevious: {},
            onNext: {}
        )
        .frame(width: 430, height: 330)
        .background(Color.black)
    }
}
#endif

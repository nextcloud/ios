// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import MapKit
import NextcloudKit

/// Image-only lower content. Actions and the fixed thumbnail area belong to the shared adaptive panel.
struct NCImageAdaptiveControlsView: View {
    let metadata: tableMetadata
    let exif: ExifData?
    let isShowingInformation: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    summary
                    if isShowingInformation {
                        information
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .clipped()

            pageActions
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .foregroundStyle(.white)
        .fontWeight(.bold)
        .tint(.white)
        .environment(\.colorScheme, .dark)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(metadata.fileNameView.isEmpty ? metadata.fileName : metadata.fileNameView)
                .font(.headline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            // File date is the fallback; never describe it as an EXIF capture date.
            Text(exif?.date ?? metadata.date as Date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.white)

            if let cameraText {
                Label(cameraText, systemImage: "camera")
                    .font(.subheadline)
            }

            Text(fileValues.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.white)

            if !isShowingInformation, let location = availableText(exif?.location) {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var pageActions: some View {
        HStack(spacing: 3) {
            pageButton(systemName: "chevron.left", title: "_previous_media_", isEnabled: canGoPrevious, action: onPrevious)
            pageButton(systemName: "chevron.right", title: "_next_media_", isEnabled: canGoNext, action: onNext)
        }
    }

    private func pageButton(systemName: String, title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(NSLocalizedString(title, comment: ""), systemImage: systemName)
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    @ViewBuilder
    private var information: some View {
        if let lens = availableText(exif?.lensModel) {
            Text(lens)
                .font(.subheadline)
                .foregroundStyle(.white)
        }

        if !exposureValues.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 3)], spacing: 3) {
                ForEach(Array(exposureValues.enumerated()), id: \.offset) { _, value in
                    Text(value)
                        .font(.subheadline.monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }

        if let coordinate {
            Button {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                item.name = availableText(exif?.location)
                item.openInMaps()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    if NCNetworking.shared.isOnline {
                        Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500))) {
                            Marker("", coordinate: coordinate)
                        }
                        .allowsHitTesting(false)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Label(availableText(exif?.location) ?? "\(coordinate.latitude.formatted()), \(coordinate.longitude.formatted())", systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if let location = availableText(exif?.location) {
            Label(location, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    private var cameraText: String? {
        let make = availableText(exif?.make)
        let model = availableText(exif?.model)
        if let make, let model, model.localizedCaseInsensitiveContains(make) {
            return model
        }
        let values = [make, model].compactMap { $0 }
        return values.isEmpty ? nil : values.joined(separator: " ")
    }

    private var fileValues: [String] {
        var values: [String] = []
        if let format = availableText(metadata.fileExtension) {
            values.append(format.uppercased())
        }
        let width = exif?.width ?? metadata.width
        let height = exif?.height ?? metadata.height
        if width > 0, height > 0 {
            values.append("\(width) × \(height)")
        }
        if metadata.size > 0 {
            values.append(NCUtilityFileSystem().transformedSize(metadata.size))
        }
        return values
    }

    private var exposureValues: [String] {
        [
            exif?.iso.map { "ISO \($0)" },
            exif?.lensLength.map { "\($0) mm" },
            exif?.exposureValue.map { "\($0) EV" },
            exif?.apertureValue.map { "ƒ/\($0.formatted())" },
            exif?.shutterSpeedApex.flatMap { apex -> String? in
                let denominator = pow(2, apex)
                guard denominator.isFinite, denominator > 0 else { return nil }
                return denominator >= 1 ? "1/\(denominator.formatted(.number.precision(.fractionLength(0)))) s" : "\((1 / denominator).formatted()) s"
            }
        ].compactMap { $0 }
    }

    private var coordinate: CLLocationCoordinate2D? {
        let latitude = exif?.latitude ?? (metadata.latitude != 0 ? metadata.latitude : nil)
        let longitude = exif?.longitude ?? (metadata.longitude != 0 ? metadata.longitude : nil)
        guard let latitude, let longitude else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    private func availableText(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}

#if DEBUG
#Preview("Adaptive Image - Summary") {
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
            exif: exif,
            isShowingInformation: isShowingInformation,
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

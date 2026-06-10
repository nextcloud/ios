// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import MapKit
import NextcloudKit

// MARK: - Media Viewer Detail View
struct NCMediaViewerDetailView: View {
    let metadata: tableMetadata
    let exif: ExifData

    private let utilityFileSystem = NCUtilityFileSystem()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                dateSection
                mediaSummaryCard
                locationSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ncViewerBackground(.system))
        .presentationBackground(Color.ncViewerBackground(.system))
    }

    private var mediaSummaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(cameraText)
                    .font(.body)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if !metadata.fileExtension.isEmpty {
                    detailBadge(metadata.fileExtension.uppercased())
                }

                if metadata.isLivePhoto {
                    Image(systemName: "livephoto")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.secondary.opacity(0.10))

            VStack(alignment: .leading, spacing: 10) {
                Text(lensText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                FlowingDetailValues(values: primaryMediaValues)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !exifStripValues.isEmpty {
                Divider()

                HStack(spacing: 0) {
                    ForEach(Array(exifStripValues.enumerated()), id: \.offset) { index, value in
                        Text(value)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)

                        if index < exifStripValues.count - 1 {
                            Divider()
                                .frame(height: 22)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
        }
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Sections

    @ViewBuilder
    private var dateSection: some View {
        if let date = exif.date as Date? {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayString(from: date))
                    .font(.body)

                HStack(spacing: 8) {
                    Text(dateString(from: date))
                    Text(timeString(from: date))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } else {
            Text(NSLocalizedString("_no_date_information_", comment: ""))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cameraText)
                .font(.headline)

            Text(lensText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var lensSection: some View {
        let values = lensValues

        if !values.isEmpty {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 90), spacing: 8)
                ],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(values, id: \.self) { value in
                    detailBadge(value)
                }
            }
        }
    }

    @ViewBuilder
    private var exposureSection: some View {
        let values = exposureValues

        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("EXIF")
                    .font(.headline)

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 90), spacing: 8)
                    ],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(values, id: \.self) { value in
                        detailBadge(value)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        if let latitude = exif.latitude,
           let longitude = exif.longitude,
           NCNetworking.shared.isOnline {
            let coordinate = CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )

            VStack(spacing: 0) {
                ZStack {
                    Map(
                        initialPosition: .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                latitudinalMeters: 500,
                                longitudinalMeters: 500
                            )
                        )
                    ) {
                        Marker("", coordinate: coordinate)
                    }
                    .allowsHitTesting(false)

                    Button {
                        openMaps(
                            coordinate: coordinate,
                            name: exif.location
                        )
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 180)

                if let location = exif.location, !location.isEmpty {
                    Button {
                        openMaps(
                            coordinate: coordinate,
                            name: location
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Text(location)
                                .lineLimit(1)
                                .foregroundStyle(.tint)

                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(.secondary.opacity(0.08))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if let location = exif.location, !location.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                Text(location)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Small Views

    private func detailBadge(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                .secondary.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
    }

    // MARK: - Computed Values

    private var primaryMediaValues: [String] {
        var values: [String] = []

        if let megapixelsText {
            values.append(megapixelsText)
        }

        if let resolutionText {
            values.append(resolutionText)
        }

        values.append(utilityFileSystem.transformedSize(metadata.size))

        if metadata.isLivePhoto {
            values.append("LIVE")
        }

        return values
    }

    private var exifStripValues: [String] {
        var values: [String] = []

        if let iso = exif.iso {
            values.append("ISO \(iso)")
        }

        if let lensLength = exif.lensLength {
            values.append("\(lensLength) mm")
        }

        if let exposureValue = exif.exposureValue {
            values.append("\(exposureValue) ev")
        }

        if let apertureValue = exif.apertureValue {
            values.append("ƒ\(apertureValue)")
        }

        if let shutterSpeedApex = exif.shutterSpeedApex {
            values.append("1/\(Int(pow(2, shutterSpeedApex))) s")
        }

        return values
    }

    private var fileNameWithoutExtension: String {
        (metadata.fileNameView as NSString).deletingPathExtension
    }

    private var cameraText: String {
        guard let make = exif.make,
              let model = exif.model else {
            return NSLocalizedString("_no_camera_information_", comment: "")
        }

        return "\(make) \(model)"
    }

    private var lensText: String {
        guard let make = exif.make,
              let model = exif.model,
              let lensModel = exif.lensModel else {
            return NSLocalizedString("_no_lens_information_", comment: "")
        }

        return lensModel
            .replacingOccurrences(of: make, with: "")
            .replacingOccurrences(of: model, with: "")
            .replacingOccurrences(of: "f/", with: "ƒ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .firstUppercased
    }

    private var resolutionText: String? {
        guard let width = exif.width,
              let height = exif.height else {
            return nil
        }

        return "\(width) x \(height)"
    }

    private var megapixelsText: String? {
        guard let width = exif.width,
              let height = exif.height else {
            return nil
        }

        let megapixels = Double(width * height) / 1_000_000

        return megapixels < 1
        ? String(format: "%.1f MP", megapixels)
        : "\(Int(megapixels)) MP"
    }

    private var lensValues: [String] {
        var values: [String] = []

        if let lensLength = exif.lensLength {
            values.append("\(lensLength) mm")
        }

        if let apertureValue = exif.apertureValue {
            values.append("ƒ\(apertureValue)")
        }

        return values
    }

    private var exposureValues: [String] {
        var values: [String] = []

        if let shutterSpeedApex = exif.shutterSpeedApex {
            values.append("1/\(Int(pow(2, shutterSpeedApex))) s")
        }

        if let iso = exif.iso {
            values.append("ISO \(iso)")
        }

        if let exposureValue = exif.exposureValue {
            values.append("\(exposureValue) ev")
        }

        return values
    }

    // MARK: - Formatters

    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Actions

    private func openMaps(
        coordinate: CLLocationCoordinate2D,
        name: String?
    ) {
        let placemark = MKPlacemark(
            coordinate: coordinate,
            addressDictionary: nil
        )

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps()
    }
}

// Helper view for flowing detail values
private struct FlowingDetailValues: View {
    let values: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                detailValues
            }

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 92), spacing: 8)
                ],
                alignment: .leading,
                spacing: 4
            ) {
                detailValues
            }
        }
    }

    @ViewBuilder
    private var detailValues: some View {
        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
            HStack(spacing: 6) {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if index < values.count - 1 {
                    Text("•")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Full EXIF") {
    let metadata: tableMetadata = {
        let metadata = tableMetadata()
        metadata.fileNameView = "IMG_0042.HEIC"
        metadata.size = 3_145_728
        metadata.livePhotoFile = "IMG_0042.MOV"
        return metadata
    }()

    let exif: ExifData = {
        var exif = ExifData()
        exif.make = "Apple"
        exif.model = "iPhone 17 Pro"
        exif.lensModel = "iPhone 17 Pro back triple camera 6.765mm f/1.78"
        exif.width = 5712
        exif.height = 4284
        exif.iso = 64
        exif.lensLength = 7
        exif.exposureValue = 0
        exif.apertureValue = 1.78
        exif.shutterSpeedApex = 9.0
        exif.latitude = 48.137154
        exif.longitude = 11.576124
        exif.location = "Munich, Germany"
        exif.date = Date(timeIntervalSince1970: 1_750_000_000)
        return exif
    }()

    NCMediaViewerDetailView(metadata: metadata, exif: exif)
}

#Preview("No EXIF") {
    let metadata: tableMetadata = {
        let metadata = tableMetadata()
        metadata.fileNameView = "Document scan.png"
        metadata.size = 482_133
        return metadata
    }()

    NCMediaViewerDetailView(metadata: metadata, exif: ExifData())
}

// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import MapKit
import NextcloudKit

// MARK: - Media Viewer Detail View

/// SwiftUI detail panel for media viewer metadata.
///
/// It renders file information, optional EXIF information, and optional location data.
struct NCMediaViewerDetailView: View {
    let metadata: tableMetadata
    let exif: ExifData

    private let utilityFileSystem = NCUtilityFileSystem()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                dateSection
                fileSection
                cameraSection
                lensSection
                exposureSection
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

    // MARK: - Sections

    @ViewBuilder
    private var dateSection: some View {
        if let date = exif.date as Date? {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayString(from: date))
                    .font(.headline)

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

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fileNameWithoutExtension)
                .font(.title3.weight(.semibold))
                .lineLimit(2)

            HStack(spacing: 8) {
                if let megapixelsText {
                    detailBadge(megapixelsText)
                }

                if let resolutionText {
                    detailBadge(resolutionText)
                }

                detailBadge(utilityFileSystem.transformedSize(metadata.size))

                if !metadata.fileExtension.isEmpty {
                    detailBadge(metadata.fileExtension.uppercased())
                }

                if metadata.isLivePhoto {
                    Image(systemName: "livephoto")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
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

            VStack(alignment: .leading, spacing: 10) {
                if let location = exif.location, !location.isEmpty {
                    Button {
                        openMaps(
                            coordinate: coordinate,
                            name: location
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(location)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }

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
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .allowsHitTesting(false)
            }
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
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.secondary.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Computed Values

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

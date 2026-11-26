// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Image information shared between the viewer and the host app.
public struct NCExifData: Sendable {
    public var colorModel: String?
    public var width: Int?
    public var height: Int?
    public var dpiWidth: Int?
    public var dpiHeight: Int?
    public var depth: Int?
    public var orientation: Int?
    public var apertureValue: Double?
    public var exposureValue: Int?
    public var shutterSpeedApex: Double?
    public var iso: Int?
    public var lensLength: Int?
    public var brightnessValue: String?
    public var dateTimeDigitized: String?
    public var dateTimeOriginal: String?
    public var offsetTime: String?
    public var offsetTimeDigitized: String?
    public var offsetTimeOriginal: String?
    public var make: String?
    public var model: String?
    public var software: String?
    public var tileLength: Double?
    public var tileWidth: Double?
    public var xResolution: Double?
    public var yResolution: Double?
    public var altitude: String?
    public var destBearing: String?
    public var hPositioningError: String?
    public var imgDirection: String?
    public var latitude: Double?
    public var longitude: Double?
    public var speed: Double?
    public var location: String?
    public var lensModel: String?
    public var date: Date?

    public init() { }
}

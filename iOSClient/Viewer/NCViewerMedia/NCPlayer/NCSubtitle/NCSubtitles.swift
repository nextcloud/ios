//
//  NCSubtitles
//  Nextcloud
//
//  Created by Marc Hervera.
//  Copyright 2017 Marc Hervera AVPlayerViewController-Subtitles v1.3.1 iOS
//
//  Modified by Federico Malagoni on 23/02/22 for Nextcloud.
//
//  Licensed under Apache License v2.0.
//

import AVKit

class NCSubtitles {

    // MARK: - Private properties

    private var parsedPayload: NSDictionary?

    // MARK: - Public methods

    public init(file filePath: URL, encoding: String.Encoding = .utf8) throws {
        // Get string
        let string = try String(contentsOf: filePath, encoding: encoding)
        // Parse string
        parsedPayload = try NCSubtitles.parseSubRip(string)
    }

    public init(subtitles string: String) throws {
        // Parse string
        parsedPayload = try NCSubtitles.parseSubRip(string)
    }

    /// Search subtitles at time
    ///
    /// - Parameter time: Time
    /// - Returns: String if exists
    public func searchSubtitles(at time: TimeInterval) -> String? {
        return NCSubtitles.searchSubtitles(parsedPayload, time)
    }

    // MARK: - Static methods

    /// Subtitle parser
    ///
    /// - Parameter payload: Input string
    /// - Returns: NSDictionary
    static func parseSubRip(_ payload: String) throws -> NSDictionary? {
        // Prepare payload
        var payload = payload.replacingOccurrences(of: "\n\r\n", with: "\n\n")
        payload = payload.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        payload = payload.replacingOccurrences(of: "\r\n", with: "\n")

        // Parsed dict
        let parsed = NSMutableDictionary()

        // Get groups
        let regexStr = "(\\d+)\\n([\\d:,.]+)\\s+-{2}\\>\\s+([\\d:,.]+)\\n([\\s\\S]*?(?=\\n{2,}|$))"
        let regex = try NSRegularExpression(pattern: regexStr, options: .caseInsensitive)
        let matches = regex.matches(in: payload, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(location: 0, length: payload.count))

        for m in matches {
            let group = (payload as NSString).substring(with: m.range)

            // Get index
            var regex = try NSRegularExpression(pattern: "^[0-9]+", options: .caseInsensitive)
            var match = regex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(location: 0, length: group.count))

            guard let i = match.first else {
                continue
            }

            let index = (group as NSString).substring(with: i.range)

            // Get "from" & "to" time
            regex = try NSRegularExpression(pattern: "\\d{1,2}:\\d{1,2}:\\d{1,2}[,.]\\d{1,3}", options: .caseInsensitive)
            match = regex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(location: 0, length: group.count))

            guard match.count == 2 else {
                continue
            }

            guard let from = match.first, let to = match.last else {
                continue
            }

            var h: TimeInterval = 0.0, m: TimeInterval = 0.0, s: TimeInterval = 0.0, c: TimeInterval = 0.0

            let fromStr = (group as NSString).substring(with: from.range)
            var scanner = Scanner(string: fromStr)
            scanner.scanDouble(&h)
            scanner.scanString(":", into: nil)
            scanner.scanDouble(&m)
            scanner.scanString(":", into: nil)
            scanner.scanDouble(&s)
            scanner.scanString(",", into: nil)
            scanner.scanDouble(&c)
            let fromTime = (h * 3600.0) + (m * 60.0) + s + (c / 1000.0)

            let toStr = (group as NSString).substring(with: to.range)
            scanner = Scanner(string: toStr)
            scanner.scanDouble(&h)
            scanner.scanString(":", into: nil)
            scanner.scanDouble(&m)
            scanner.scanString(":", into: nil)
            scanner.scanDouble(&s)
            scanner.scanString(",", into: nil)
            scanner.scanDouble(&c)
            let toTime = (h * 3600.0) + (m * 60.0) + s + (c / 1000.0)

            // Get text & check if empty
            let range = NSRange(location: 0, length: to.range.location + to.range.length + 1)
            guard (group as NSString).length - range.length > 0 else {
                continue
            }

            let text = (group as NSString).replacingCharacters(in: range, with: "")

            // Create final object
            let final = NSMutableDictionary()
            final["from"] = fromTime
            final["to"] = toTime
            final["text"] = text
            parsed[index] = final
        }

        return parsed
    }

    /// Search subtitle on time
    ///
    /// - Parameters:
    ///   - payload: Inout payload
    ///   - time: Time
    /// - Returns: String
    static func searchSubtitles(_ payload: NSDictionary?, _ time: TimeInterval) -> String? {
        let predicate = NSPredicate(format: "(%f >= %K) AND (%f <= %K)", time, "from", time, "to")

        guard let values = payload?.allValues, let result = (values as NSArray).filtered(using: predicate).first as? NSDictionary else {
            return nil
        }

        guard let text = result.value(forKey: "text") as? String else {
            return nil
        }

        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

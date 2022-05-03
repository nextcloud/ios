//
//  UserAgentTests.swift
//  Nextcloud
//
//  Created by Henrik Storch on 03.05.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

@testable import Nextcloud
import XCTest

class UserAgentTests: XCTestCase {
    // https://github.com/nextcloud/server/blob/fc826e98115b510313ddacbf6fef4ce8d041e373/lib/public/IRequest.php#L83
    let ncServerUARegex = "^Mozilla\\/5\\.0 \\(iOS\\) (ownCloud|Nextcloud)\\-iOS.*$"

    // https://github.com/ProseMirror/prosemirror-view/blob/427d278aaaacde422ed1f2b8c84bb53337162775/src/browser.js#L18-L22
    let proseMirrorWebKitUARegex = "\\bAppleWebKit\\/(\\d+)"
    let proseMirroriOSUARegex = "Mobile\\/\\w+"

    func testDefaultUserAgent() throws {
        let userAgent: String = CCUtility.getUserAgent()
        let match = try matches(for: ncServerUARegex, in: userAgent).first
        XCTAssertNotNil(match)
    }

    func testTextUserAgent() throws {
        let userAgent: String = NCUtility.shared.getCustomUserAgentNCText()
        let match = try matches(for: ncServerUARegex, in: userAgent).first
        XCTAssertNotNil(match)

        let iOSMatch = try matches(for: proseMirroriOSUARegex, in: userAgent).first
        XCTAssertNotNil(iOSMatch)

        // https://github.com/ProseMirror/prosemirror-view/blob/8f246f320801f8e3cac92c97f71ac91e3e327f2f/src/input.js#L521-L522
        let webKitMatch = try matches(for: proseMirrorWebKitUARegex, in: userAgent).first
        XCTAssertNotNil(webKitMatch)
        XCTAssertEqual(webKitMatch!.numberOfRanges, 2)
        let versionRange = webKitMatch!.range(at: 1)
        let versionString = userAgent[Range(versionRange, in: userAgent)!]
        let webkitVersion = Int(versionString) ?? 0
        XCTAssertGreaterThanOrEqual(webkitVersion, 604)
    }

    func matches(for regex: String, in text: String) throws -> [NSTextCheckingResult] {
        let range = NSRange(location: 0, length: text.utf16.count)
        let regex = try NSRegularExpression(pattern: regex)
        return regex.matches(in: text, range: range)
    }
}

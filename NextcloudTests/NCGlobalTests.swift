//
//  NCGlobalTests.swift
//  Nextcloud
//
//  Created by Henrik Storch on 01.12.21.
//  Copyright © 2021 Henrik Storch. All rights reserved.
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

class NCGlobalTests: XCTestCase {

    func testSharedInatance() throws {
        XCTAssertNotNil(NCGlobal.shared, "Shared instance should be initialized")
    }

    func testHashToInt() {
        let emptyHash10 = NCGlobal.hashToInt(hash: "", maximum: 10)
        let emptyHash2 = NCGlobal.hashToInt(hash: "", maximum: 2)
        XCTAssertEqual(emptyHash10, 0, "Empty hash should be zero")
        XCTAssertEqual(emptyHash10, emptyHash2, "Empty hashes should be the same")
        let emptyHashA = NCGlobal.hashToInt(hash: "a", maximum: 10)
        XCTAssertEqual(emptyHashA, 0, "Hash of 'a' mod 10 should be zero")
        let emptyHash22 = NCGlobal.hashToInt(hash: "1ab", maximum: 100)
        XCTAssertEqual(emptyHash22, 22, "Hash of '1ab' mod 100 should be 22")
        let nonHexHash = NCGlobal.hashToInt(hash: "1qw&(*}", maximum: 10)
        XCTAssertEqual(nonHexHash, 1, "Non hex characters should be ignored")
    }

    func testUsernameToColor() {
        let color = NCGlobal.shared.usernameToColor("00000000")
        let userColor = NCBrandColor.shared.userColors[0]
        XCTAssertEqual(color, userColor, "Zero usercolor doesn't match")
        let emptyColor = NCGlobal.shared.usernameToColor("")
        let emptyUserColor = NCBrandColor.shared.userColors[12]
        XCTAssertEqual(emptyColor, emptyUserColor, "Empty usercolor doesn't match")
    }
}

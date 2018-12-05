//
//  DPITests.swift
//  PDFGenerator
//
//  Created by Suguru Kishimoto on 7/23/16.
//
//

import XCTest
@testable import PDFGenerator

class DPITests: XCTestCase {
    func test() {
        XCTAssertEqual(DPIType.default.value, 72.0)
        XCTAssertEqual(DPIType.dpi_300.value, 300.0)
        XCTAssertEqual(DPIType.custom(100.0).value, 100.0)
        XCTAssertEqual(DPIType.custom(-100.0).value, DPIType.default.value)
    }
}

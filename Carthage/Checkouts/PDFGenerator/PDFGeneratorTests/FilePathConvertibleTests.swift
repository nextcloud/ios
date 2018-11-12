//
//  FilePathConvertibleTests.swift
//  PDFGenerator
//
//  Created by Suguru Kishimoto on 7/23/16.
//
//

import XCTest
@testable import PDFGenerator

class FilePathConvertibleTests: XCTestCase {
    
    func test() {
        let p1: FilePathConvertible = ""
        XCTAssertNotNil(p1.url)
        XCTAssertEqual(p1.path, "")
        XCTAssertEqual(p1.url, URL(fileURLWithPath: ""))

        let p2: FilePathConvertible = "path/to/hoge.txt"
        XCTAssertNotNil(p2.url)
        XCTAssertEqual(p2.url, URL(fileURLWithPath: "path/to/hoge.txt"))
        XCTAssertEqual(p2.path, "path/to/hoge.txt")

        let p3: FilePathConvertible = URL(fileURLWithPath: "path/to/hoge.txt")
        XCTAssertNotNil(p3.url)
        XCTAssertEqual(p3.url, URL(fileURLWithPath: "path/to/hoge.txt"))
    }
}

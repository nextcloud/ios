//
//  PDFPasswordTests.swift
//  PDFGenerator
//
//  Created by Suguru Kishimoto on 7/23/16.
//
//

import XCTest
@testable import PDFGenerator
class PDFPasswordTests: XCTestCase {
    func test() {
        let p1: PDFPassword = "123456"
        XCTAssertEqual(p1.userPassword, "123456")
        XCTAssertEqual(p1.ownerPassword, "123456")
        do {
            try p1.verify()
        } catch _ {
            XCTFail()
        }
        
        let p2: PDFPassword = PDFPassword(user: "123456", owner: "abcdef")
        XCTAssertNotEqual(p2.userPassword, p2.ownerPassword)
        do {
            try p2.verify()
        } catch _ {
            XCTFail()
        }

        let p3: PDFPassword = PDFPassword(user: "ああああ", owner: "abcdef")
        do {
            try p3.verify()
            XCTFail()
        } catch PDFGenerateError.invalidPassword(let password) {
            XCTAssertEqual(p3.userPassword, password)
        } catch _ {
            XCTFail()
        }
        
        let p4: PDFPassword = PDFPassword(user: "123456", owner: "ああああ")
        do {
            try p4.verify()
            XCTFail()
        } catch PDFGenerateError.invalidPassword(let password) {
            XCTAssertEqual(p4.ownerPassword, password)
        } catch _ {
            XCTFail()
        }
        
        let p5: PDFPassword = PDFPassword(user: "1234567890123456789012345678901234567890", owner: "abcdef")
        do {
            try p5.verify()
            XCTFail()
        } catch PDFGenerateError.tooLongPassword(let length) {
            XCTAssertEqual(p5.userPassword.characters.count, length)
        } catch _ {
            XCTFail()
        }
        
        let p6: PDFPassword = PDFPassword(user: "123456", owner: "abcdefghijabcdefghijabcdefghijabcdefghij")
        do {
            try p6.verify()
            XCTFail()
        } catch PDFGenerateError.tooLongPassword(let length) {
            XCTAssertEqual(p6.ownerPassword.characters.count, length)
        } catch _ {
            XCTFail()
        }

    }
}

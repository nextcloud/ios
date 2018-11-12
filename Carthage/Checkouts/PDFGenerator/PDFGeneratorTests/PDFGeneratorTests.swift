//
//  PDFGeneratorTests.swift
//  PDFGeneratorTests
//
//  Created by Suguru Kishimoto on 2016/02/04.
//
//

import XCTest
@testable import PDFGenerator

class Mock {
    struct ImageName {
        static let testImage1 = "test_image1"
    }
    
    class func view(_ size: CGSize) -> UIView {
        return UIView(frame: CGRect(origin: CGPoint.zero, size: size))
    }
    
    class func scrollView(_ size: CGSize) -> UIScrollView {
        return { () -> UIScrollView in
            let v = UIScrollView(frame: CGRect(origin: CGPoint.zero, size: size))
            v.contentSize = v.frame.size
            return v
        }()
    }

    class func imagePath(_ name: String) -> String{
        return Bundle(for: self).path(forResource: name, ofType: "png")!
    }
    
    class func image(_ name: String) -> UIImage {
        return UIImage(contentsOfFile: imagePath(name))!
    }
    
}

class PDFGeneratorTests: XCTestCase {
    
    func isExistPDF(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    func PDFDirectoryPath() -> String {
        return NSHomeDirectory() + "/test/"
    }
    
    func PDFfilePath(_ fileName: String) -> String {
        return PDFDirectoryPath() + "/\(fileName)"
    }
    
    override func setUp() {
        super.setUp()
        try! FileManager.default.createDirectory(
            atPath: PDFDirectoryPath(),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    override func tearDown() {
        _ = try? FileManager.default.removeItem(atPath: PDFDirectoryPath())
        super.tearDown()
    }
    
    // MARK: UIView -> PDF
    func testViewToPDF() {
        let view = Mock.view(CGSize(width: 100, height: 100))
        let view2 = Mock.scrollView(CGSize(width: 100, height: 100))
        
        let path1 = PDFfilePath("test_sample1.pdf")
        _ = try? PDFGenerator.generate(view, to: path1)
        XCTAssertTrue(isExistPDF(path1))
        
        let path2 = PDFfilePath("hoge/test_sample2.pdf")
        _ = try? PDFGenerator.generate(view, to: path2)
        XCTAssertFalse(isExistPDF(path2))
        
        let path3 = PDFfilePath("test_sample3.pdf")
        _ = try? PDFGenerator.generate(view, to: path3)
        XCTAssertTrue(isExistPDF(path3))
        
        XCTAssertNotNil(try? PDFGenerator.generated(by: view))
        XCTAssertNotNil(try? PDFGenerator.generated(by: [view]))
        XCTAssertNotNil(try? PDFGenerator.generated(by: [view, view2]))
    }
    
    // MARK: UIImage -> PDF
    func testImageToPDF() {
        let image1 = Mock.image("test_image1")
        let image2 = Mock.image("test_image1")
        
        let path1 = PDFfilePath("test_sample1.pdf")
        _ = try? PDFGenerator.generate(image1, to: path1)
        XCTAssertTrue(isExistPDF(path1))
        
        let path2 = PDFfilePath("hoge/test_sample2.pdf")
        _ = try? PDFGenerator.generate(image1, to: path2)
        XCTAssertFalse(isExistPDF(path2))
        
        let path3 = PDFfilePath("test_sample3.pdf")
        _ = try? PDFGenerator.generate([image1, image2], to: path3)
        XCTAssertTrue(isExistPDF(path3))
        
        XCTAssertNotNil(try? PDFGenerator.generated(by: image1))
        XCTAssertNotNil(try? PDFGenerator.generated(by: [image1]))
        XCTAssertNotNil(try? PDFGenerator.generated(by: [image1, image2]))
    }
    
    // MARK: ImagePath(String) -> PDF
    func testImagePathToPDF() {
        let image1 = Mock.imagePath("test_image1")
        let image2 = Mock.imagePath("test_image1")
        
        let path1 = PDFfilePath("test_sample1.pdf")
        _ = try? PDFGenerator.generate(image1, to: path1)
        XCTAssertTrue(isExistPDF(path1))
        
        let path2 = PDFfilePath("hoge/test_sample2.pdf")
        _ = try? PDFGenerator.generate(image1, to: path2)
        XCTAssertFalse(isExistPDF(path2))
        
        let path3 = PDFfilePath("test_sample3.pdf")
        _ = try? PDFGenerator.generate([image1, image2], to: path3)
        XCTAssertTrue(isExistPDF(path3))
        
        XCTAssertNotNil(try? PDFGenerator.generated(by: image1))
        XCTAssertNotNil(try? PDFGenerator.generated(by: [image1]))
        XCTAssertNotNil(try? PDFGenerator.generated(by: [image1, image2]))
    }
    
    // MARK: PDFPage -> PDF
    func testMixedPageToPDF() {
        let p1 = PDFPage.view(Mock.view(CGSize(width: 100, height: 100)))
        let p2 = PDFPage.image(Mock.image(Mock.ImageName.testImage1))
        let p3 = PDFPage.imagePath(Mock.imagePath(Mock.ImageName.testImage1))
        let p4 = PDFPage.whitePage(CGSize(width: 100, height: 100))
        let p5 = PDFPage.imageRef(Mock.image(Mock.ImageName.testImage1).cgImage!)
        let p6 = PDFPage.binary(UIImagePNGRepresentation(Mock.image(Mock.ImageName.testImage1))!)
        
        let path1 = PDFfilePath("test_sample1.pdf")
        _ = try? PDFGenerator.generate(p1, to: path1)
        XCTAssertTrue(isExistPDF(path1))

        let path2 = PDFfilePath("hoge/test_sample2.pdf")
        _ = try? PDFGenerator.generate(p2, to: path2)
        XCTAssertFalse(isExistPDF(path2))
        
        let path3 = PDFfilePath("test_sample3.pdf")
        _ = try? PDFGenerator.generate([p1, p2, p3, p4], to: path3)
        XCTAssertTrue(isExistPDF(path3))

        XCTAssertNotNil(try? PDFGenerator.generated(by: p1))
        XCTAssertNotNil(try? PDFGenerator.generated(by: [p2]))
        XCTAssertNotNil(try? PDFGenerator.generated(by: [p3, p4]))
        XCTAssertNotNil(try? PDFGenerator.generated(by: [p5, p6]))

    }
    
    // swiftlint:disable function_body_length
    func testErrors() {
        let view = Mock.view(CGSize(width: 100, height: 100))
        let image = Mock.image(Mock.ImageName.testImage1)
        let imagePath = Mock.imagePath(Mock.ImageName.testImage1)
        let viewPage = PDFPage.view(Mock.view(CGSize(width: 100, height: 100)))
        let imagePage = PDFPage.image(Mock.image(Mock.ImageName.testImage1))
        let imagePathPage = PDFPage.imagePath(Mock.imagePath(Mock.ImageName.testImage1))
        let whitePage = PDFPage.whitePage(CGSize(width: 100, height: 100))
        let views = [
            Mock.view(CGSize(width: 100, height: 100)),
            Mock.view(CGSize(width: 100, height: 100))
        ]
        let images = [
            Mock.image(Mock.ImageName.testImage1),
            Mock.image(Mock.ImageName.testImage1)
        ]
        let imagePaths = [
            Mock.imagePath(Mock.ImageName.testImage1),
            Mock.imagePath(Mock.ImageName.testImage1)
        ]
        
        let pages = [
            PDFPage.view(Mock.view(CGSize(width: 100, height: 100))),
            PDFPage.image(Mock.image(Mock.ImageName.testImage1)),
            PDFPage.imagePath(Mock.imagePath(Mock.ImageName.testImage1)),
            PDFPage.whitePage(CGSize(width: 100, height: 100))
        ]

        let mocks: [Any] = [
            view,
            image,
            imagePath,
            viewPage,
            imagePage,
            imagePathPage,
            whitePage,
            views,
            images,
            imagePaths,
            pages
        ]
        
        let emptyMocks: [Any] = [
            [UIView](),
            [UIImage](),
            [String](),
            [PDFPage]()
        ]
        
        // MARK: check EmptyOutputPath
        mocks.forEach {
            do {
                if let page = $0 as? UIView {
                    try PDFGenerator.generate(page, to: "")
                } else if let page = $0 as? UIImage {
                    try PDFGenerator.generate(page, to: "")
                } else if let page = $0 as? String {
                    try PDFGenerator.generate(page, to: "")
                } else if let page = $0 as? PDFPage {
                    try PDFGenerator.generate(page, to: "")
                } else if let pages = $0 as? [UIView] {
                    try PDFGenerator.generate(pages, to: "")
                } else if let pages = $0 as? [UIImage] {
                    try PDFGenerator.generate(pages, to: "")
                } else if let pages = $0 as? [String] {
                    try PDFGenerator.generate(pages, to: "")
                } else if let pages = $0 as? [PDFPage] {
                    try PDFGenerator.generate(pages, to: "")
                } else {
                    XCTFail("invalid page(s) type found.")
                }
                XCTFail("[\($0)] No create PDF from empty name image path.")
            } catch PDFGenerateError.emptyOutputPath {
                // Right Error
            } catch (let e) {
                XCTFail("[\($0)] Unknown or wrong error occurred.\(e)")
            }
        }
        
        // MARK: check EmptyPage
        emptyMocks.forEach {
            do {
                let path = PDFfilePath("test_sample1.pdf")
                if let pages = $0 as? [UIView] {
                    try PDFGenerator.generate(pages, to: path)
                } else if let pages = $0 as? [UIImage] {
                    try PDFGenerator.generate(pages, to: path)
                } else if let pages = $0 as? [String] {
                    try PDFGenerator.generate(pages, to: path)
                } else if let pages = $0 as? [PDFPage] {
                    try PDFGenerator.generate(pages, to: path)
                } else {
                    XCTFail("invalid pages type found.")
                }
                XCTFail("[\($0)] No create PDF from empty name image path.")
            } catch PDFGenerateError.emptyPage {
                // Right Error
            } catch (let e) {
                XCTFail("[\($0)] Unknown or wrong error occurred.\(e)")
            }
        }
        
        // MARK: check EmptyPage
        emptyMocks.forEach {
            do {
                if let pages = $0 as? [UIView] {
                    _ = try PDFGenerator.generated(by: pages)
                } else if let pages = $0 as? [UIImage] {
                    _ = try PDFGenerator.generated(by: pages)
                } else if let pages = $0 as? [String] {
                    _ = try PDFGenerator.generated(by: pages)
                } else if let pages = $0 as? [PDFPage] {
                    _ = try PDFGenerator.generated(by: pages)
                } else {
                    XCTFail("invalid pages type found.")
                }
                XCTFail("[\($0)] No create PDF from empty name image path.")
            } catch PDFGenerateError.emptyPage {
                // Right Error
            } catch (let e) {
                XCTFail("[\($0)] Unknown or wrong error occurred.\(e)")
            }
        }
        
        // MARK: check ZeroSizeView
        let emptyView = Mock.view(CGSize.zero)
        do {
            let path = PDFfilePath("test_sample2.pdf")
            try PDFGenerator.generate(emptyView, to: path)
        } catch PDFGenerateError.zeroSizeView(let v) {
            XCTAssertEqual(emptyView, v)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        do {
            _ = try PDFGenerator.generated(by: emptyView)
        } catch PDFGenerateError.zeroSizeView(let v) {
            XCTAssertEqual(emptyView, v)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        do {
            _ = try PDFGenerator.generated(by: [emptyView])
        } catch PDFGenerateError.zeroSizeView(let v) {
            XCTAssertEqual(emptyView, v)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        
        let emptyViewPage = PDFPage.view(emptyView)
        do {
            let path = PDFfilePath("test_sample3.pdf")
            try PDFGenerator.generate(emptyViewPage, to: path)
        } catch PDFGenerateError.zeroSizeView(let v) {
            XCTAssertEqual(emptyView, v)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        do {
            _ = try PDFGenerator.generated(by: emptyViewPage)
        } catch PDFGenerateError.zeroSizeView(let v) {
            XCTAssertEqual(emptyView, v)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        do {
            _ = try PDFGenerator.generated(by: [emptyViewPage])
        } catch PDFGenerateError.zeroSizeView(let v) {
            XCTAssertEqual(emptyView, v)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }

        // MARK: check ImageLoadFailed
        let wrongImagePath = "wrong/image.png"
        do {
            let path = PDFfilePath("test_sample4.pdf")
            try PDFGenerator.generate(wrongImagePath, to: path)
        } catch PDFGenerateError.imageLoadFailed(let ip) {
            XCTAssertEqual(wrongImagePath, ip as? String)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        do {
            _ = try PDFGenerator.generated(by: wrongImagePath)
        } catch PDFGenerateError.imageLoadFailed(let ip) {
            XCTAssertEqual(wrongImagePath, ip as? String)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        do {
            _ = try PDFGenerator.generated(by: [wrongImagePath])
        } catch PDFGenerateError.imageLoadFailed(let ip) {
            XCTAssertEqual(wrongImagePath, ip as? String)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }

        let wrongImagePathPage = PDFPage.imagePath(wrongImagePath)
        do {
            let path = PDFfilePath("test_sample5.pdf")
            try PDFGenerator.generate(wrongImagePathPage, to: path)
        } catch PDFGenerateError.imageLoadFailed(let ip) {
            XCTAssertEqual(wrongImagePath, ip as? String)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        do {
            _ = try PDFGenerator.generated(by: wrongImagePathPage)
        } catch PDFGenerateError.imageLoadFailed(let ip) {
            XCTAssertEqual(wrongImagePath, ip as? String)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        do {
            _ = try PDFGenerator.generated(by: [wrongImagePathPage])
        } catch PDFGenerateError.imageLoadFailed(let ip) {
            XCTAssertEqual(wrongImagePath, ip as? String)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }
        
        let wrongData = Data()
        
        do {
            _ = try PDFGenerator.generated(by: PDFPage.binary(wrongData))
        } catch PDFGenerateError.imageLoadFailed(let data) {
            XCTAssertEqual(wrongData, data as? Data)
        } catch (let e) {
            XCTFail("Unknown or wrong error occurred.\(e)")
        }

    }
    // swiftlint:enable function_body_length
    
    func testPDFPassword() {
        let view = Mock.view(CGSize(width: 100, height: 100))
        let view2 = Mock.view(CGSize(width: 100, height: 100))
        
        let path1 = PDFfilePath("test_sample1.pdf")
        _ = try? PDFGenerator.generate(view, to: path1, password: "abcdef")
        XCTAssertTrue(isExistPDF(path1))
        
        let path2 = PDFfilePath("test_sample2.pdf")
        _ = try? PDFGenerator.generate(view, to: path2, password: "⌘123456")
        XCTAssertFalse(isExistPDF(path2))
        
        let path3 = PDFfilePath("test_sample3.pdf")
        do {
            try PDFGenerator.generate([view, view2], to: path3, password: "123456")
        } catch {
            XCTFail()
        }

        let path4 = PDFfilePath("test_sample4.pdf")
        do {
            try PDFGenerator.generate([view, view2], to: path4, password: "⌘123456")
            XCTFail()
        } catch PDFGenerateError.invalidPassword(let password) {
            XCTAssertEqual(password, "⌘123456")
        } catch {
            XCTFail()
        }

        let path5 = PDFfilePath("test_sample5.pdf")
        do {
            try PDFGenerator.generate([view, view2], to: path5, password: "0123456789abcdef0123456789abcdefA")
            XCTFail()
        } catch PDFGenerateError.tooLongPassword(let length) {
            XCTAssertEqual(length, 33)
        } catch {
            XCTFail()
        }

        XCTAssertNotNil(try? PDFGenerator.generated(by: view, password: "abcdef"))
        XCTAssertNil(try? PDFGenerator.generated(by: [view], password: "⌘123456"))
        
        do {
            _ = try PDFGenerator.generated(by: [view], password: "123456")
        } catch {
            XCTFail()
        }

        do {
            _ = try PDFGenerator.generated(by: [view], password: "⌘123456")
        } catch PDFGenerateError.invalidPassword(let password) {
            XCTAssertEqual(password, "⌘123456")
        } catch {
            XCTFail()
        }
        
        do {
            _ = try PDFGenerator.generated(by: [view], password: "0123456789abcdef0123456789abcdefA")
            XCTFail()
        } catch PDFGenerateError.tooLongPassword(let length) {
            XCTAssertEqual(length, 33)
        } catch {
            XCTFail()
        }
    }
}

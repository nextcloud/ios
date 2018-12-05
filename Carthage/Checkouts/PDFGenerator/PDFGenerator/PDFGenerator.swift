//
//  PDFGenerator.swift
//  PDFGenerator
//
//  Created by Suguru Kishimoto on 2016/02/04.
//
//

import Foundation
import UIKit

/// PDFGenerator
public final class PDFGenerator {
    fileprivate typealias Process = () throws -> Void
    
    /// Avoid creating instance.
    fileprivate init() {}
    
    /**
     Generate from page object.
     
     - parameter page:       A `PDFPage`'s object.
     - parameter outputPath: An outputPath to save PDF.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     */
    public class func generate(_ page: PDFPage, to path: FilePathConvertible, dpi: DPIType = .default, password: PDFPassword = "") throws {
        try generate([page], to: path, dpi: dpi, password: password)
    }
    
    /**
     Generate from page objects.
     
     - parameter pages:      Array of `PDFPage`'s objects.
     - parameter outputPath: An outputPath to save PDF.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     */
    public class func generate(_ pages: [PDFPage], to path: FilePathConvertible, dpi: DPIType = .default, password: PDFPassword = "") throws {
        guard !pages.isEmpty else {
            throw PDFGenerateError.emptyPage
        }
        guard !path.isEmptyPath else {
            throw PDFGenerateError.emptyOutputPath
        }
        do {
            try render(to: path, password: password) {
                try render(pages, dpi: dpi)
            }
        } catch let error {
            _ = try? FileManager.default.removeItem(at: path.url)
            throw error
        }
    }
    
    /**
     Generate from view.
     
     - parameter view:       A view
     - parameter outputPath: An outputPath to save PDF.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     */
    public class func generate(_ view: UIView, to path: FilePathConvertible, dpi: DPIType = .default, password: PDFPassword = "") throws {
        try generate([view], to: path, dpi: dpi, password: password)
    }
    
    /**
     Generate from views.
     
     - parameter views:      Array of views.
     - parameter outputPath: An outputPath to save PDF.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     */
    public class func generate(_ views: [UIView], to path: FilePathConvertible, dpi: DPIType = .default, password: PDFPassword = "") throws {
        try generate(PDFPage.pages(views), to: path, dpi: dpi, password: password)
    }
    
    /**
     Generate from image.
     
     - parameter image:      An image.
     - parameter outputPath: An outputPath to save PDF.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     */
    public class func generate(_ image: UIImage, to path: FilePathConvertible, dpi: DPIType = .default, password: PDFPassword = "") throws {
        try generate([image], to: path, dpi: dpi, password: password)
    }
    
    /**
     Generate from images.
     
     - parameter images:     Array of images.
     - parameter outputPath: An outputPath to save PDF.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     */
    public class func generate(_ images: [UIImage], to path: FilePathConvertible, dpi: DPIType = .default, password: PDFPassword = "") throws {
        try generate(PDFPage.pages(images), to: path, dpi: dpi, password: password)
    }

    /**
     Generate from image path.
     
     - parameter imagePath:  An image path.
     - parameter outputPath: An outputPath to save PDF.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     */
    public class func generate(_ imagePath: String, to path: FilePathConvertible, dpi: DPIType = .default, password: PDFPassword = "") throws {
        try generate([imagePath], to: path, dpi: dpi, password: password)
    }
    
    /**
     Generate from image paths.
     
     - parameter imagePaths: Arrat of image paths.
     - parameter outputPath: An outputPath to save PDF.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     */
    public class func generate(_ imagePaths: [String], to path: FilePathConvertible, dpi: DPIType = .default, password: PDFPassword = "") throws {
        try generate(PDFPage.pages(imagePaths), to: path, dpi: dpi, password: password)
    }
    
    /**
     Generate from page object.
     
     - parameter page: A `PDFPage`'s object.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     
     - returns: PDF's binary data (NSData)
     */
    
    public class func generated(by page: PDFPage, dpi: DPIType = .default, password: PDFPassword = "") throws -> Data {
        return try generated(by: [page], dpi: dpi, password: password)
    }

    /**
     Generate from page objects.
     
     - parameter pages: Array of `PDFPage`'s objects.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     
     - returns: PDF's binary data (NSData)
     */
    
    public class func generated(by pages: [PDFPage], dpi: DPIType = .default, password: PDFPassword = "") throws -> Data {
        guard !pages.isEmpty else {
            throw PDFGenerateError.emptyPage
        }
        return try rendered(with: password) { try render(pages, dpi: dpi) }
    }

    /**
     Generate from view.
     
     - parameter view: A view
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     
     - returns: PDF's binary data (NSData)
     */
    
    public class func generated(by view: UIView, dpi: DPIType = .default, password: PDFPassword = "") throws -> Data {
        return try generated(by: [view], dpi: dpi, password: password)
    }

    /**
     Generate from views.
     
     - parameter views: Array of views.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     
     - returns: PDF's binary data (NSData)
     */
    
    public class func generated(by views: [UIView], dpi: DPIType = .default, password: PDFPassword = "") throws -> Data  {
        return try generated(by: PDFPage.pages(views), dpi: dpi, password: password)
    }
    
    /**
     Generate from image.
     
     - parameter image: An image.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     
     - returns: PDF's binary data (NSData)
     */
    
    public class func generated(by image: UIImage, dpi: DPIType = .default, password: PDFPassword = "") throws -> Data {
        return try generated(by: [image], dpi: dpi, password: password)
    }

    /**
     Generate from images.
     
     - parameter images: Array of images.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     
     - returns: PDF's binary data (NSData)
     */
    
    public class func generated(by images: [UIImage], dpi: DPIType = .default, password: PDFPassword = "") throws -> Data {
        return try generated(by: PDFPage.pages(images), dpi: dpi, password: password)
    }
    
    /**
     Generate from image path.
     
     - parameter imagePath: An image path.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     
     - returns: PDF's binary data (NSData)
     */
    
    public class func generated(by imagePath: String, dpi: DPIType = .default, password: PDFPassword = "") throws -> Data {
        return try generated(by: [imagePath], dpi: dpi, password: password)
    }
    
    /**
     Generate from image paths.
     
     - parameter imagePaths: Arrat of image paths.
     
     - throws: A `PDFGenerateError` thrown if some error occurred.
     
     - returns: PDF's binary data (NSData)
     */
    
    public class func generated(by imagePaths: [String], dpi: DPIType = .default, password: PDFPassword = "") throws -> Data {
        return try generated(by: PDFPage.pages(imagePaths), dpi: dpi, password: password)
    }
}

// MARK: Private Extension

/// PDFGenerator private extensions (render processes)
private extension PDFGenerator {
    class func render(_ page: PDFPage, dpi: DPIType) throws {
        let scaleFactor = dpi.scaleFactor
        
        try autoreleasepool {
            switch page {
            case .whitePage(let size):
                let view = UIView(frame: CGRect(origin: .zero, size: size))
                view.backgroundColor = .white
                try view.renderPDFPage(scaleFactor: scaleFactor)
            case .view(let view):
                try view.renderPDFPage(scaleFactor: scaleFactor)
            case .image(let image):
                try image.asUIImage().renderPDFPage(scaleFactor: scaleFactor)
            case .imagePath(let ip):
                try ip.asUIImage().renderPDFPage(scaleFactor: scaleFactor)
            case .binary(let data):
                try data.asUIImage().renderPDFPage(scaleFactor: scaleFactor)
            case .imageRef(let cgImage):
                try cgImage.asUIImage().renderPDFPage(scaleFactor: scaleFactor)
            }
        }
    }
    
    class func render(_ pages: [PDFPage], dpi: DPIType) throws {
        try pages.forEach { try render($0, dpi: dpi) }
    }
    
    class func render(to path: FilePathConvertible, password: PDFPassword, process: Process) rethrows {
        try { try password.verify() }()
        UIGraphicsBeginPDFContextToFile(path.path, .zero, password.toDocumentInfo())
        try process()
        UIGraphicsEndPDFContext()
    }
    
    class func rendered(with password: PDFPassword, process: Process) rethrows -> Data {
        try { try password.verify() }()
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, .zero, password.toDocumentInfo())
        try process()
        UIGraphicsEndPDFContext()
        return data as Data
    }
}

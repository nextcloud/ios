//
//  RotateImageTest.swift
//  NextcloudTests
//
//  Created by A200020526 on 26/04/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

@testable import Nextcloud
import XCTest

class RotateImageTest: XCTestCase {
    
    //Test that the function returns the same image when the rotation angle is 0 radians
    func testRotateZeroRadians() {
        let image = UIImage(named: "logo")!
        let rotatedImage = image.rotate(radians: 0)
        XCTAssertEqual(rotatedImage?.pngData(), image.pngData())
    }
    
    //Test that the function returns a different image when the rotation angle is not 0 radians
    func testRotateNonZeroRadians() {
        let image = UIImage(named: "logo")!
        let rotatedImage = image.rotate(radians: Float.pi / 2) // rotate 90 degrees
        XCTAssertNotEqual(rotatedImage?.pngData(), image.pngData())
    }
    
    //Test that the function returns a valid image when the original image has a valid jpegData
    func testRotateValidJPEGData() {
        let image = UIImage(named: "logo")!
        let rotatedImage = image.rotate(radians: Float.pi / 2)
        XCTAssertNotNil(rotatedImage?.pngData())
    }
    
    //Test for orientation UIImage.Orientation.up which should return the original image
    func testRotateExif_withOrientationUp_returnsOriginalImage() {
        // Given
        let image = UIImage(named: "logo")
        let originalOrientation = image?.imageOrientation
        
        // When
        let rotatedImage = image?.rotateExif(orientation: .up)
        
        // Then
        XCTAssertEqual(originalOrientation, rotatedImage?.imageOrientation)
    }

    //Test for orientation UIImage.Orientation.left which should rotate the image 90 degrees clockwise
    func testRotateExif_withOrientationLeft_rotatesImage90DegreesClockwise() {
        // Given
        let image = UIImage(named: "logo")
        let originalOrientation = image?.imageOrientation
        
        // When
        let rotatedImage = image?.rotateExif(orientation: .left)
        
        // Then
        XCTAssertEqual((originalOrientation?.rawValue ?? 0) + 2, rotatedImage?.imageOrientation.rawValue)
    }
    
    //Test for orientation UIImage.Orientation.down which should rotate the image 180 degrees
    func testRotateExif_withOrientationDown_rotatesImage180Degrees() {
        // Given
        let image = UIImage(named: "logo")
        let originalOrientation = image?.imageOrientation
        
        // When
        let rotatedImage = image?.rotateExif(orientation: .down)
        
        // Then
        XCTAssertEqual((originalOrientation?.rawValue ?? 0) + 1, rotatedImage?.imageOrientation.rawValue)
    }

    //Test for orientation UIImage.Orientation.right which should rotate the image 270 degrees clockwise
    func testRotateExif_withOrientationRight_rotatesImage270DegreesClockwise() {
        // Given
        let image = UIImage(named: "logo")
        let originalOrientation = image?.imageOrientation
        
        // When
        let rotatedImage = image?.rotateExif(orientation: .right)
        
        // Then
        XCTAssertEqual((originalOrientation?.rawValue ?? 0) + 3, rotatedImage?.imageOrientation.rawValue)
    }

}

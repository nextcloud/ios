//
//  AudioUploadTests.swift
//  NextcloudTests
//
//  Created by A200020526 on 13/06/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import XCTest
@testable import Nextcloud

final class AudioUploadTests: XCTestCase {
    var viewController:NCAudioRecorderViewController?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Step 1. Create an instance of UIStoryboard
        let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as? NCAudioRecorderViewController
        // Step 3. Make the viewDidLoad() execute.
        viewController?.loadViewIfNeeded()
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        viewController = nil
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testAudioMeterUpdateAfterDb(){
        viewController?.audioMeterDidUpdate(0.5)
        XCTAssertNotNil(!(viewController?.durationLabel.text?.isEmpty ?? false))
    }

    func testStartRecorder(){
        viewController?.startStop()
        XCTAssertEqual(viewController?.recording.state, nil, "Test start audio recorder")
    }
}

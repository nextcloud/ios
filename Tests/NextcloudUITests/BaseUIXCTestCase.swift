//
//  BaseUIXCTestCase.swift
//  NextcloudUITests
//
//  Created by Milen on 20.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import XCTest

class BaseUIXCTestCase: XCTestCase {
    let timeoutSeconds: Double = 100

    override final class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    internal func waitForEnabled(object: Any?) {
        let predicate = NSPredicate(format: "enabled == true")
        expectation(for: predicate, evaluatedWith: object, handler: nil)
        waitForExpectations(timeout: timeoutSeconds, handler: nil)
    }

    internal func waitForHittable(object: Any?) {
        let predicate = NSPredicate(format: "hittable == true")
        expectation(for: predicate, evaluatedWith: object, handler: nil)
        waitForExpectations(timeout: timeoutSeconds, handler: nil)
    }

    internal func waitForEnabledAndHittable(object: Any?) {
        waitForEnabled(object: object)
        waitForHittable(object: object)
    }
}


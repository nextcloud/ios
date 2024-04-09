//
//  BaseUIXCTestCase.swift
//  NextcloudUITests
//
//  Created by Milen on 20.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

import XCTest

class BaseUIXCTestCase: BaseXCTestCase {    
    let timeoutSeconds: Double = 300

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


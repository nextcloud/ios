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

<<<<<<< HEAD
class BaseUIXCTestCase: XCTestCase {
    let timeoutSeconds: Double = 100

=======
class BaseUIXCTestCase: BaseXCTestCase {
>>>>>>> aa28af8228d8d3d97f2f5aa16076333e8c0faf95
    override final class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    internal func waitForEnabled(object: Any?) {
        let predicate = NSPredicate(format: "enabled == true")
        expectation(for: predicate, evaluatedWith: object, handler: nil)
<<<<<<< HEAD
        waitForExpectations(timeout: timeoutSeconds, handler: nil)
=======
        waitForExpectations(timeout: TestConstants.timeoutLong, handler: nil)
>>>>>>> aa28af8228d8d3d97f2f5aa16076333e8c0faf95
    }

    internal func waitForHittable(object: Any?) {
        let predicate = NSPredicate(format: "hittable == true")
        expectation(for: predicate, evaluatedWith: object, handler: nil)
<<<<<<< HEAD
        waitForExpectations(timeout: timeoutSeconds, handler: nil)
=======
        waitForExpectations(timeout: TestConstants.timeoutLong, handler: nil)
>>>>>>> aa28af8228d8d3d97f2f5aa16076333e8c0faf95
    }

    internal func waitForEnabledAndHittable(object: Any?) {
        waitForEnabled(object: object)
        waitForHittable(object: object)
    }
}


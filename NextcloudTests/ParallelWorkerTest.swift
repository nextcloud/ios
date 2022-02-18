//
//  ParallelWorkerTest.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.02.22.
//  Copyright © 2021 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

@testable import Nextcloud
import XCTest

class ParallelWorkerTest: XCTestCase {

    func testWorkerComplete() throws {
        let expectation = XCTestExpectation(description: "Worker executes all tasks")
        let taskCount = 20
        var tasksComplete = 0
        let worker = ParallelWorker(n: 5, titleKey: nil, totalTasks: nil, hudView: nil)
        for _ in 0..<taskCount {
            worker.execute { completion in
                tasksComplete += 1
                completion()
            }
        }
        worker.completeWork {
            XCTAssertEqual(tasksComplete, taskCount)
            if tasksComplete == taskCount {
                expectation.fulfill()
            }
        }

        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed)
    }

    func testWorkerOrder() throws {
        let expectation = XCTestExpectation(description: "Worker executes work in sequence for n = 1")
        let sortedArray = Array(0..<20)
        var array: [Int] = []
        let worker = ParallelWorker(n: 1, titleKey: nil, totalTasks: nil, hudView: nil)
        for i in sortedArray {
            worker.execute { completion in
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.2)) {
                    array.append(i)
                    completion()
                }
            }
        }
        worker.completeWork {
            XCTAssertEqual(sortedArray, array)
            if sortedArray == array {
                expectation.fulfill()
            }
        }
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed)
    }

    func testWorkerFailsWithoutCompletion() throws {
        let expectation = XCTestExpectation(description: "Worker fails if completion isn't called")
        expectation.isInverted = true
        let worker = ParallelWorker(n: 5, titleKey: nil, totalTasks: nil, hudView: nil)
        for _ in 0..<20 {
            worker.execute { _ in }
        }
        worker.completeWork { expectation.fulfill() }
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed)
    }
}

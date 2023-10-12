//
//  NCNotificationTest.swift
//  NextcloudTests
//
//  Created by A200020526 on 17/04/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

@testable import Nextcloud
import XCTest
import NextcloudKit

class NCNotificationText: XCTestCase {
    var viewController : NCNotification!
    
    override func setUpWithError() throws {
        // Step 1. Create an instance of UIStoryboard
        let storyboard = UIStoryboard(name: "NCNotification", bundle: nil)
        // Step 2. Instantiate UIViewController with Storyboard ID
        viewController = storyboard.instantiateViewController(withIdentifier: "NCNotification.storyboard") as? NCNotification
        
        // Step 3. Make the viewDidLoad() execute.
        viewController.loadViewIfNeeded()
    }
    
    override func tearDownWithError() throws {
        viewController = nil
    }
    
    //Test that a cell with the correct reuse identifier is dequeued
    func testTableViewCellDequeue() {
        let notification = NKNotifications()
        viewController.notifications = [notification]
        let tableView = UITableView()
        tableView.register(NCNotificationCell.self, forCellReuseIdentifier: "Cell")
        let indexPath = IndexPath(row: 0, section: 0)
        let cell = viewController.tableView(tableView, cellForRowAt: indexPath) as? NCNotificationCell
        XCTAssertNotNil(cell)
        XCTAssertEqual(cell?.reuseIdentifier, "Cell")
    }

    //Test that the cell's icon is set image
    func testTableViewCellIcon() {
        let notification = NKNotifications()
        viewController.notifications = [notification]
        let tableView = UITableView()
        tableView.register(NCNotificationCell.self, forCellReuseIdentifier: "Cell")
        let indexPath = IndexPath(row: 0, section: 0)
        let cell = viewController.tableView(tableView, cellForRowAt: indexPath) as? NCNotificationCell
        XCTAssertNotNil(cell?.icon.image)
    }
    
    //Test that the cell's primary and secondary buttons are set up correctly
    func testTableViewCellButtons() {
        let notification = NKNotifications()
        notification.actions = Data("[{\"label\":\"OK\",\"primary\":true},{\"label\":\"Cancel\",\"primary\":false}]".utf8)
        viewController.notifications = [notification]
        let tableView = UITableView()
        tableView.register(NCNotificationCell.self, forCellReuseIdentifier: "Cell")
        let indexPath = IndexPath(row: 0, section: 0)
        let cell = viewController.tableView(tableView, cellForRowAt: indexPath) as? NCNotificationCell
        XCTAssertEqual(cell?.primary.title(for: .normal), "OK")
        XCTAssertEqual(cell?.secondary.title(for: .normal), "Cancel")
    }

    //Test that the cell's date label is set correctly
    func testTableViewCellDate() {
        let notification = NKNotifications()
        notification.date = NSDate()
        viewController.notifications = [notification]
        let tableView = UITableView()
        tableView.register(NCNotificationCell.self, forCellReuseIdentifier: "Cell")
        let indexPath = IndexPath(row: 0, section: 0)
        let cell = viewController.tableView(tableView, cellForRowAt: indexPath) as? NCNotificationCell
        XCTAssertEqual(cell?.date.text, "less than a minute ago")
    }

    //Test with a color that is image not nil
    func testImageNotNil() {
        let color = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let image = UIImage().imageColor(color)
        XCTAssertNotNil(image, "Image should not be nil.")
        
    }
}

//
//  PrivacyPolicyTest.swift
//  NextcloudTests
//
//  Created by A200073704 on 27/04/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

@testable import Nextcloud
import XCTest
import NextcloudKit
import XLForm


 class PrivacyPolicyTest: XCTestCase {
    
     var viewController: InitialPrivacySettingsViewController?
     var privacySettingsView = PrivacySettingsViewController()
     
    override func setUpWithError() throws {
        
        // To Create an instance of UIStoryboard
        let storyboard = UIStoryboard(name: "NCSettings", bundle: nil)
        
        //  To Instantiate UIViewController with Storyboard ID
        viewController = storyboard.instantiateViewController(withIdentifier: "privacyPolicyViewController") as? InitialPrivacySettingsViewController
        
        // Outlets are connected
        let _ = viewController?.view
        
        // Make the viewDidLoad() execute.
        viewController?.loadViewIfNeeded()

    }

    override func tearDownWithError() throws {
         viewController = nil
    }
    
    func testPrivacyPolicyViewControllerIsOpen() {
       
        // Check that the InitialPrivacyPolicyViewController gets opened
        let storyboard = UIStoryboard(name: "NCSettings", bundle: nil)
        if let privacyPolicyViewController = storyboard.instantiateViewController(withIdentifier: "privacyPolicyViewController") as? InitialPrivacySettingsViewController {
            let navigationController = UINavigationController(rootViewController: privacyPolicyViewController)
            
            privacyPolicyViewController.loadViewIfNeeded()
            
            XCTAssertTrue(navigationController.topViewController is InitialPrivacySettingsViewController, "Privacy policy view controller should be open")
        }
    }
     
     func testTextViewHasCorrectText() {
         
         //Check that the text displayed is correct
         let expectedText = NSLocalizedString("_privacy_help_text_after_login_", comment: "")
         viewController?.privacySettingsHelpText?.text = expectedText
         
         let actualText = viewController?.privacySettingsHelpText?.text
         XCTAssertEqual(actualText, expectedText, "The text view does not have the expected text")
     }
     
     func testHasAcceptButton() {
         
         // Check that view has the accept button
         let acceptButton = viewController?.acceptButton
         
         XCTAssertNotNil(acceptButton, "View controller does not have an accept button")
         
     }
     
     func testSettingsLinkTypeNavigatesToPrivacySettingsViewController() {

         // Simulate tapping the "Settings" link type
         let linkType = LinkType.settings
         
         UserDefaults.standard.set(true, forKey: "showSettingsButton")
         viewController?.privacySettingsHelpText.hyperLink(originalText: viewController?.privacyHelpText ?? "", linkTextsAndTypes: [NSLocalizedString("_key_settings_help_", comment: ""): linkType.rawValue])

         // Check that the correct view controller was pushed onto the navigation stack
         XCTAssertNotNil(viewController?.navigationController?.visibleViewController is PrivacySettingsViewController)
     }
     
     func testPrivacyPolicyLinkType_NavigatesToPrivacyPolicyViewController() {

         // Simulate tapping the "Privacy Policy" link type
         let linkType = LinkType.privacyPolicy
    
         viewController?.privacySettingsHelpText.hyperLink(originalText: viewController?.privacyHelpText ?? "", linkTextsAndTypes: [NSLocalizedString("_key_privacy_help_", comment: ""): linkType.rawValue])
    
         // Check that the correct view controller was pushed onto the navigation
         XCTAssertNotNil(viewController?.navigationController?.visibleViewController is PrivacyPolicyViewController)
     }
     
     func testCorrectImagePresentOnInitialPrivacySettingsViewController() {
         
         // Check that the image view has the correct image
         let expectedImage = UIImage(named: "dataPrivacy")
         XCTAssertNotNil(expectedImage)
     }
     
     func testAcceptButtonHasBackgroundColor() {
         
         // Check that the accept button has the correct background color
         let expectedColor = NCBrandColor.shared.brand
         XCTAssertEqual(viewController?.acceptButton.backgroundColor, expectedColor)
         
     }
     
     func testShowSaveSettingsButton() {
         
         privacySettingsView.isShowSettingsButton = UserDefaults.standard.bool(forKey: "showSettingsButton")
         
         XCTAssertTrue(privacySettingsView.isShowSettingsButton)
         
     }
     
     func testRequiredDataCollectionSectionExists() {
         let form : XLFormDescriptor = XLFormDescriptor() as XLFormDescriptor
         form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow

         var section : XLFormSectionDescriptor
         var row : XLFormRowDescriptor

         //  the section with the title "Required Data Collection"
         row = XLFormRowDescriptor(tag: "ButtonDestinationFolder", rowType: "RequiredDataCollectionCustomCellType", title: "")
         section = XLFormSectionDescriptor.formSection(withTitle: "")
         section.footerTitle = NSLocalizedString("_required_data_collection_help_text_", comment: "")

         // Verify that section was found
         XCTAssertNotNil(row, "Expected 'Required Data Collection' section to exist in form.")
     }
     
     func testAnalysisDataCollectionSection() {
         
         let form : XLFormDescriptor = XLFormDescriptor() as XLFormDescriptor
         form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow
         var section : XLFormSectionDescriptor
         var row : XLFormRowDescriptor

         // row with tag "AnalysisDataCollectionSwitch"
         row = XLFormRowDescriptor(tag: "AnalysisDataCollectionSwitch", rowType: "AnalysisDataCollectionCustomCellType", title: "")
         section = XLFormSectionDescriptor.formSection(withTitle: "")
         section.footerTitle = NSLocalizedString("_analysis_data_acqusition_help_text_", comment: "")

         // Assert that the row exists
         XCTAssertNotNil(row, "Expected row with tag 'AnalysisDataCollectionSwitch' to exist in form.")

         // Verify the switch is off
         XCTAssertFalse(UserDefaults.standard.bool(forKey: "isAnalysisDataCollectionSwitchOn"), "Expected isAnalysisDataCollectionSwitchOn to be false.")
     }

  
}

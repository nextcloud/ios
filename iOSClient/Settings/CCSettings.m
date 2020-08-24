//
//  CCSettings.m
//  Nextcloud
//
//  Created by Marino Faggiana on 24/11/14.
//  Copyright (c) 2014 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

#import "CCSettings.h"
#import "AppDelegate.h"
#import "CCMain.h"
#import "CCAdvanced.h"
#import "CCManageAccount.h"
#import "NCManageEndToEndEncryption.h"
#import "NCBridgeSwift.h"
#import <TOPasscodeViewController/TOPasscodeViewController.h>


#define alertViewEsci 1
#define alertViewAzzeraCache 2

@interface CCSettings () <TOPasscodeSettingsViewControllerDelegate, TOPasscodeViewControllerDelegate>
{
    AppDelegate *appDelegate;
    TOPasscodeViewController *passcodeViewController;
    TOPasscodeSettingsViewController *passcodeSettingsViewController;
}
@end

@implementation CCSettings

- (void)initializeForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    //NSInteger serverVersionMajor = [[NCManageDatabase sharedInstance] getCapabilitiesServerIntWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesVersionMajor];
    
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    // Section AUTO UPLOAD OF CAMERA IMAGES ----------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUpload" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_settings_autoupload_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"autoUpload"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    row.action.viewControllerClass = [CCManageAutoUpload class];
    [section addFormRow:row];

    // Section FOLDERS FAVORITES OFFLINE ------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"favoriteoffline" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_favorite_offline_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Section : LOCK --------------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_lock_", nil)];
    [form addFormSection:section];
    
    // Lock active YES/NO
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"bloccopasscode" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_lock_not_active_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"settingsPasscodeNO"] multiplier:2 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    //[row.cellConfig setObject:@(UITableViewCellAccessoryDisclosureIndicator) forKey:@"accessoryType"];
    row.action.formSelector = @selector(passcode:);
    [section addFormRow:row];
    // Enable Touch ID
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"enableTouchDaceID" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_enable_touch_face_id_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    // Lock no screen
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"notPasscodeAtStart" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_lock_protection_no_screen_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Section : Screen --------------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_screen_", nil)];
    [form addFormSection:section];
    
    // Dark Mode
    if (@available(iOS 13.0, *)) {
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"darkModeDetect" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_dark_mode_detect_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"darkModeDetect"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        if ([CCUtility getDarkModeDetect]) row.value = @1;
        else row.value = @0;
        [section addFormRow:row];
        
    } else {
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"darkMode" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_dark_mode_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"themeLightDark"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        if ([CCUtility getDarkMode]) row.value = @1;
        else row.value = @0;
        [section addFormRow:row];
    }
    
    // Section : E2EEncryption --------------------------------------------------------------
        
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_e2e_settings_title_", nil)];
    [form addFormSection:section];
    
    // EndToEnd Encryption
    NSString *title = [NSString stringWithFormat:@"%@ (%@)",NSLocalizedString(@"_e2e_settings_", nil), NSLocalizedString(@"_experimental_", nil)];
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"e2eEncryption" rowType:XLFormRowDescriptorTypeButton title:title];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"lock"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    row.action.viewControllerClass = [NCManageEndToEndEncryption class];
    
    [section addFormRow:row];
    
    // Section Advanced -------------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Advanced
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"advanced" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_advanced_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"settings"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    row.action.viewControllerClass = [CCAdvanced class];
    [section addFormRow:row];

    // Section : INFORMATION ------------------------------------------------

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_information_", nil)];
    [form addFormSection:section];
    
    // Acknowledgements
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"buttonLeftAligned" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_acknowledgements_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"acknowledgements"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    row.action.formBlock = ^(XLFormRowDescriptor * sender){
        [self performSegueWithIdentifier:@"AcknowledgementsSegue" sender:sender];
        [self deselectFormRow:sender];
    };
    [section addFormRow:row];
    
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 35, 0);
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_settings_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:k_notificationCenter_changeTheming object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:k_notificationCenter_applicationDidEnterBackground object:nil];

    [self changeTheming];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:self.tableView collectionView:nil form:true];
    [self initializeForm];
    [self reloadForm];
}

- (void)applicationDidEnterBackground
{
    if (passcodeViewController.view.window != nil) {
        [passcodeViewController dismissViewControllerAnimated:true completion:nil];
    }
    if (passcodeSettingsViewController.view.window != nil) {
        [passcodeSettingsViewController dismissViewControllerAnimated:true completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Chiamate dal Form ===
#pragma --------------------------------------------------------------------------------------------

- (void)reloadForm
{
    self.form.delegate = nil;
    
    // ------------------------------------------------------------------

    XLFormRowDescriptor *rowBloccoPasscode = [self.form formRowWithTag:@"bloccopasscode"];
    XLFormRowDescriptor *rowNotPasscodeAtStart = [self.form formRowWithTag:@"notPasscodeAtStart"];
    XLFormRowDescriptor *rowEnableTouchDaceID = [self.form formRowWithTag:@"enableTouchDaceID"];
    XLFormRowDescriptor *rowFavoriteOffline = [self.form formRowWithTag:@"favoriteoffline"];
    XLFormRowDescriptor *rowDarkModeDetect = [self.form formRowWithTag:@"darkModeDetect"];
    XLFormRowDescriptor *rowDarkMode = [self.form formRowWithTag:@"darkMode"];

    // ------------------------------------------------------------------
    
    if ([[CCUtility getPasscode] length]) {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"settingsPasscodeYES"] multiplier:2 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    } else {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_not_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"settingsPasscodeNO"] multiplier:2 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    }
    
    if ([CCUtility getEnableTouchFaceID]) [rowEnableTouchDaceID setValue:@1]; else [rowEnableTouchDaceID setValue:@0];
    if ([CCUtility getNotPasscodeAtStart]) [rowNotPasscodeAtStart setValue:@1]; else [rowNotPasscodeAtStart setValue:@0];
    if ([CCUtility getFavoriteOffline]) [rowFavoriteOffline setValue:@1]; else [rowFavoriteOffline setValue:@0];
    if ([CCUtility getDarkModeDetect]) [rowDarkModeDetect setValue:@1]; else [rowDarkModeDetect setValue:@0];
    if ([CCUtility getDarkMode]) [rowDarkMode setValue:@1]; else [rowDarkMode setValue:@0];

    // -----------------------------------------------------------------
    
    [self.tableView reloadData];
    
    self.form.delegate = self;
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"notPasscodeAtStart"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setNotPasscodeAtStart:true];
        } else {
            [CCUtility setNotPasscodeAtStart:false];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"enableTouchDaceID"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setEnableTouchFaceID:true];
        } else {
            [CCUtility setEnableTouchFaceID:false];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"favoriteoffline"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"_continue_request_", nil) preferredStyle:UIAlertControllerStyleActionSheet];
            
            [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                [CCUtility setFavoriteOffline:true];
                [[NCNetworking shared] listingFavoritescompletionWithSelector:(selectorDownloadAllFile) completion:^(NSString *account, NSArray *metadatas, NSInteger errorCode, NSString *errorDescription) { }];                    
            }]];
            
            [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [self reloadForm];
            }]];
            
            alertController.popoverPresentationController.sourceView = self.view;
            NSIndexPath *indexPath = [self.form indexPathOfFormRow:rowDescriptor];
            CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
            alertController.popoverPresentationController.sourceRect = CGRectOffset(cellRect, -self.tableView.contentOffset.x, -self.tableView.contentOffset.y);
            
            [self presentViewController:alertController animated:YES completion:nil];
            
        } else {
            
            [CCUtility setFavoriteOffline:false];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"darkMode"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setDarkMode:true];
        } else {
            [CCUtility setDarkMode:false];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_changeTheming object:nil];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"darkModeDetect"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setDarkModeDetect:true];
            // detect Dark Mode
            if (@available(iOS 12.0, *)) {
                appDelegate.preferredUserInterfaceStyle = self.traitCollection.userInterfaceStyle;
                if (appDelegate.preferredUserInterfaceStyle == UIUserInterfaceStyleDark) {
                    [CCUtility setDarkMode:YES];
                } else {
                    [CCUtility setDarkMode:NO];
                }
            }
        } else {
            [CCUtility setDarkModeDetect:false];
            [CCUtility setDarkMode:false];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_changeTheming object:nil];
    }
}

#pragma mark - Passcode -

- (void)didPerformBiometricValidationRequestInPasscodeViewController:(TOPasscodeViewController *)passcodeViewController
{
    [[LAContext new] evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[[NCBrandOptions sharedInstance] brand] reply:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                [CCUtility setPasscode:@""];
                [passcodeViewController dismissViewControllerAnimated:YES completion:nil];
                [self reloadForm];
            });
        }
    }];
}

- (void)passcodeSettingsViewController:(TOPasscodeSettingsViewController *)passcodeSettingsViewController didChangeToNewPasscode:(NSString *)passcode ofType:(TOPasscodeType)type
{
    [CCUtility setPasscode:passcode];
    [passcodeSettingsViewController dismissViewControllerAnimated:YES completion:nil];
    
    [self reloadForm];
}

- (void)didTapCancelInPasscodeViewController:(TOPasscodeViewController *)passcodeViewController
{
    [passcodeViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)passcodeViewController:(TOPasscodeViewController *)passcodeViewController isCorrectCode:(NSString *)code
{
    if ([code isEqualToString:[CCUtility getPasscode]]) {
        [CCUtility setPasscode:@""];
        [self reloadForm];
        
        return YES;
    }
         
    return NO;
}

- (void)passcode:(XLFormRowDescriptor *)sender
{
    LAContext *laContext = [LAContext new];
    NSError *error;
    
    [self deselectFormRow:sender];

    if ([[CCUtility getPasscode] length] == 0) {
        
        passcodeSettingsViewController = [[TOPasscodeSettingsViewController alloc] init];
        if (@available(iOS 13.0, *)) {
            if ([[UITraitCollection currentTraitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark) {
                passcodeSettingsViewController.style = TOPasscodeSettingsViewStyleDark;
            }
        }
        
        passcodeSettingsViewController.hideOptionsButton = YES;
        passcodeSettingsViewController.requireCurrentPasscode = NO;
        passcodeSettingsViewController.passcodeType = TOPasscodeTypeSixDigits;
        passcodeSettingsViewController.delegate = self;
        
        [self presentViewController:passcodeSettingsViewController animated:YES completion:nil];
        
    } else {
     
        passcodeViewController = [[TOPasscodeViewController alloc] initWithStyle:TOPasscodeViewStyleTranslucentLight passcodeType:TOPasscodeTypeSixDigits];
        if (@available(iOS 13.0, *)) {
            if ([[UITraitCollection currentTraitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark) {
                passcodeViewController.style = TOPasscodeViewStyleTranslucentDark;
            }
        }
        
        passcodeViewController.allowCancel = true;
        passcodeViewController.delegate = self;
        passcodeViewController.keypadButtonShowLettering = false;
        
        if (CCUtility.getEnableTouchFaceID && [laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
            if (error == NULL) {
                if (laContext.biometryType == LABiometryTypeFaceID) {
                    passcodeViewController.biometryType = TOPasscodeBiometryTypeFaceID;
                    passcodeViewController.allowBiometricValidation = true;
                    passcodeViewController.automaticallyPromptForBiometricValidation = true;
                } else if (laContext.biometryType == LABiometryTypeTouchID) {
                    passcodeViewController.biometryType = TOPasscodeBiometryTypeTouchID;
                    passcodeViewController.allowBiometricValidation = true;
                    passcodeViewController.automaticallyPromptForBiometricValidation = true;
                } else {
                    NSLog(@"No Biometric support");
                }
            }
        }

        [self presentViewController:passcodeViewController animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Table View ===
#pragma --------------------------------------------------------------------------------------------

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSString *sectionName;
    
    switch (section)
    {
        case 1: {
            sectionName = NSLocalizedString(@"_favorite_offline_footer_", nil);
        }
        break;
        case 2: {
            sectionName = NSLocalizedString(@"_lock_protection_no_screen_footer_", nil);
        }
        break;
        case 5: {
                                
            NSString *versionServer = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesVersionString];
            NSString *themingName = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesThemingName];
            NSString *themingSlogan = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesThemingSlogan];

            NSString *versionApp = [NSString stringWithFormat:@"%@.%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
            
            NSString *versionNextcloud = [NSString stringWithFormat:[NCBrandOptions sharedInstance].textCopyrightNextcloudServer, versionServer];
            NSString *versionNextcloudiOS = [NSString stringWithFormat:[NCBrandOptions sharedInstance].textCopyrightNextcloudiOS, versionApp];
            
            NSString *nameSlogan = [NSString stringWithFormat:@"%@ - %@", themingName, themingSlogan];
            
            sectionName = [NSString stringWithFormat:@"%@\n\n%@\n%@", versionNextcloudiOS, versionNextcloud, nameSlogan];
        }
        break;
    }
    return sectionName;
}

@end

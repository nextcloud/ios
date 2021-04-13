//
//  NCSettings.m
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

#import "NCSettings.h"
#import "CCAdvanced.h"
#import "CCManageAccount.h"
#import "CCManageAutoUpload.h"
#import "NCManageEndToEndEncryption.h"
#import "NCBridgeSwift.h"
#import "NSNotificationCenter+MainThread.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <TOPasscodeViewController/TOPasscodeViewController.h>

#define alertViewEsci 1
#define alertViewAzzeraCache 2

@interface NCSettings () <TOPasscodeSettingsViewControllerDelegate, TOPasscodeViewControllerDelegate>
{
    AppDelegate *appDelegate;
    TOPasscodeViewController *passcodeViewController;
    TOPasscodeSettingsViewController *passcodeSettingsViewController;
}
@end

@implementation NCSettings

- (void)initializeForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    //NSInteger serverVersionMajor = [[NCManageDatabase shared] getCapabilitiesServerIntWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesVersionMajor];
    
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    // Section AUTO UPLOAD OF CAMERA IMAGES ----------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUpload" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_settings_autoupload_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"autoUpload"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
    row.action.viewControllerClass = [CCManageAutoUpload class];
    [section addFormRow:row];

    // Section : LOCK --------------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_lock_", nil)];
    [form addFormSection:section];
    
    // Lock active YES/NO
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"bloccopasscode" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_lock_not_active_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
    [row.cellConfig setObject:[[UIImage imageNamed:@"lock.open"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    //[row.cellConfig setObject:@(UITableViewCellAccessoryDisclosureIndicator) forKey:@"accessoryType"];
    row.action.formSelector = @selector(passcode:);
    [section addFormRow:row];
    // Enable Touch ID
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"enableTouchDaceID" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_enable_touch_face_id_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    // Lock no screen
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"notPasscodeAtStart" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_lock_protection_no_screen_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Section : Screen --------------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_screen_", nil)];
    [form addFormSection:section];
    
    // Dark Mode
    if (@available(iOS 13.0, *)) {
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"darkModeDetect" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_dark_mode_detect_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[[UIImage imageNamed:@"themeLightDark"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        if ([CCUtility getDarkModeDetect]) row.value = @1;
        else row.value = @0;
        [section addFormRow:row];
        
    } else {
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"darkMode" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_dark_mode_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[[UIImage imageNamed:@"themeLightDark"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
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
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"lock"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
    row.action.viewControllerClass = [NCManageEndToEndEncryption class];
    
    [section addFormRow:row];
    
    // Section Advanced -------------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Advanced
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"advanced" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_advanced_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"gear"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
    row.action.viewControllerClass = [CCAdvanced class];
    [section addFormRow:row];

    // Section : INFORMATION ------------------------------------------------

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_information_", nil)];
    [form addFormSection:section];
    
    // Acknowledgements
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"buttonLeftAligned" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_acknowledgements_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"acknowledgements"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
    row.action.formBlock = ^(XLFormRowDescriptor * sender){
        [self performSegueWithIdentifier:@"AcknowledgementsSegue" sender:sender];
        [self deselectFormRow:sender];
    };
    [section addFormRow:row];
    
    if (!NCBrandOptions.shared.disable_crash_service) {
        
        // Privacy
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"privacy" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_privacy_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"shield.checkerboard"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.action.formSelector = @selector(privacy:);
        [section addFormRow:row];
        
        // Source code
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sourcecode" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_source_code_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"gitHub"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.action.formSelector = @selector(sourceCode:);
        [section addFormRow:row];
    }
    
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 35, 0);
    self.form = form;
}

#pragma mark - Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_settings_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:NCGlobal.shared.notificationCenterChangeTheming object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:NCGlobal.shared.notificationCenterApplicationDidEnterBackground object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initializeMain) name:NCGlobal.shared.notificationCenterInitializeMain object:nil];

    [self changeTheming];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    appDelegate.activeViewController = self;
    
    [self initializeForm];
    [self reloadForm];
}

#pragma mark - NotificationCenter

- (void)changeTheming
{
    self.view.backgroundColor = NCBrandColor.shared.backgroundForm;
    self.tableView.backgroundColor = NCBrandColor.shared.backgroundForm;
    
    [self initializeForm];
    [self reloadForm];
}

- (void)initializeMain
{
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

#pragma mark -

- (void)reloadForm
{
    self.form.delegate = nil;
    
    // ------------------------------------------------------------------

    XLFormRowDescriptor *rowBloccoPasscode = [self.form formRowWithTag:@"bloccopasscode"];
    XLFormRowDescriptor *rowNotPasscodeAtStart = [self.form formRowWithTag:@"notPasscodeAtStart"];
    XLFormRowDescriptor *rowEnableTouchDaceID = [self.form formRowWithTag:@"enableTouchDaceID"];
    XLFormRowDescriptor *rowDarkModeDetect = [self.form formRowWithTag:@"darkModeDetect"];
    XLFormRowDescriptor *rowDarkMode = [self.form formRowWithTag:@"darkMode"];

    // ------------------------------------------------------------------
    
    if ([[CCUtility getPasscode] length]) {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[[UIImage imageNamed:@"lock"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
    } else {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_not_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[[UIImage imageNamed:@"lock.open"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
    }
    
    if ([CCUtility getEnableTouchFaceID]) [rowEnableTouchDaceID setValue:@1]; else [rowEnableTouchDaceID setValue:@0];
    if ([CCUtility getNotPasscodeAtStart]) [rowNotPasscodeAtStart setValue:@1]; else [rowNotPasscodeAtStart setValue:@0];
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
    
    if ([rowDescriptor.tag isEqualToString:@"darkMode"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setDarkMode:true];
        } else {
            [CCUtility setDarkMode:false];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCGlobal.shared.notificationCenterChangeTheming object:nil];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"darkModeDetect"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setDarkModeDetect:true];
            // detect Dark Mode
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                [CCUtility setDarkMode:YES];
            } else {
                [CCUtility setDarkMode:NO];
            }
        } else {
            [CCUtility setDarkModeDetect:false];
            [CCUtility setDarkMode:false];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCGlobal.shared.notificationCenterChangeTheming object:nil];
    }
}

#pragma mark -

- (void)privacy:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    NCBrowserWeb* browserWebVC = [[UIStoryboard storyboardWithName:@"NCBrowserWeb" bundle:nil] instantiateInitialViewController];
    
    browserWebVC.urlBase = NCBrandOptions.shared.privacy;
    browserWebVC.isHiddenButtonExit = false;
    browserWebVC.titleBrowser = NSLocalizedString(@"_privacy_", nil);
    
    [self presentViewController:browserWebVC animated:YES completion:nil];
}

- (void)sourceCode:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    NCBrowserWeb* browserWebVC = [[UIStoryboard storyboardWithName:@"NCBrowserWeb" bundle:nil] instantiateInitialViewController];
    
    browserWebVC.urlBase = NCBrandOptions.shared.sourceCode;
    browserWebVC.isHiddenButtonExit = false;
    browserWebVC.titleBrowser = NSLocalizedString(@"_source_code_", nil);
    
    [self presentViewController:browserWebVC animated:YES completion:nil];
}

#pragma mark - Passcode

- (void)didPerformBiometricValidationRequestInPasscodeViewController:(TOPasscodeViewController *)passcodeViewController
{
    [[LAContext new] evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[[NCBrandOptions shared] brand] reply:^(BOOL success, NSError * _Nullable error) {
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

#pragma mark -

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSString *sectionName;
    
    switch (section)
    {
        case 1: {
            sectionName = NSLocalizedString(@"_lock_protection_no_screen_footer_", nil);
        }
        break;
        case 5: {
                                
            NSString *versionServer = [[NCManageDatabase shared] getCapabilitiesServerStringWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesVersionString];
            NSString *themingName = [[NCManageDatabase shared] getCapabilitiesServerStringWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesThemingName];
            NSString *themingSlogan = [[NCManageDatabase shared] getCapabilitiesServerStringWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesThemingSlogan];

            NSString *versionNextcloud = [NSString stringWithFormat:[NCBrandOptions shared].textCopyrightNextcloudServer, versionServer];
            NSString *versionNextcloudiOS = [NSString stringWithFormat:[NCBrandOptions shared].textCopyrightNextcloudiOS, NCUtility.shared.getVersionApp];
            
            NSString *nameSlogan = [NSString stringWithFormat:@"%@ - %@", themingName, themingSlogan];
            
            sectionName = [NSString stringWithFormat:@"\n%@\n\n%@\n%@", versionNextcloudiOS, versionNextcloud, nameSlogan];
        }
        break;
    }
    return sectionName;
}

@end

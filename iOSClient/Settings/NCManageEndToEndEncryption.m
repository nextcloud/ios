//
//  NCManageEndToEndEncryption.m
//  Nextcloud
//
//  Created by Marino Faggiana on 13/10/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
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

#import "NCManageEndToEndEncryption.h"
#import "NSNotificationCenter+MainThread.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <TOPasscodeViewController/TOPasscodeViewController.h>
#import "NCBridgeSwift.h"
#import "CCUtility.h"

@interface NCManageEndToEndEncryption () <NCEndToEndInitializeDelegate, TOPasscodeViewControllerDelegate>
{
    AppDelegate *appDelegate;
    NSString *passcodeType;
    TOPasscodeViewController *passcodeViewController;
}
@end

@implementation NCManageEndToEndEncryption

- (void)initializeForm:(NKError *)error
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    BOOL isE2EEEnabled = [[NCManageDatabase shared] getCapabilitiesServerBoolWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesE2EEEnabled exists:false];
    NSString *versionE2EE = [[NCManageDatabase shared] getCapabilitiesServerStringWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesE2EEApiVersion];
    
    if (![versionE2EE isEqual:[[NCGlobal shared] e2eeVersion]] && isE2EEEnabled) {
        NKError *error = [[NKError alloc] initWithErrorCode:NCGlobal.shared.errorInternalError errorDescription:@"_err_e2ee_app_version_"];
        [[NCContentPresenter shared] messageNotification:@"_error_e2ee_" error:error delay:[[NCGlobal shared] dismissAfterSecond] type:messageTypeError];
    }

    if ([CCUtility isEndToEndEnabled:appDelegate.account]) {
        
        // Section SERVICE ACTIVATED -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSection];
        section.footerTitle = [NSString stringWithFormat:@"End-to-End Encryption %@", versionE2EE];
        [form addFormSection:section];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"serviceActivated" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_e2e_settings_activated_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[[UIImage imageNamed:@"checkmark.circle.fill"] imageWithColor:[UIColor greenColor] size:25] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [section addFormRow:row];
        
        // Section PASSPHRASE -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        // Read Passphrase
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"readPassphrase" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_e2e_settings_read_passphrase_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[[UIImage imageNamed:@"e2eReadPassphrase"] imageWithColor:NCBrandColor.shared.gray size:25] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(readPassphrase:);
        [section addFormRow:row];
        
        // Section DELETE -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        // remove locally Encryption
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"removeLocallyEncryption" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_e2e_settings_remove_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[[UIImage imageNamed:@"lock"] imageWithColor:NCBrandColor.shared.gray size:25] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(removeLocallyEncryption:);
        [section addFormRow:row];
        
    } else {
        
        // Section START E2E -------------------------------------------------

        section = [XLFormSectionDescriptor formSection];
        if (error == nil) {
            section.footerTitle = NSLocalizedString(@"_status_in_progress_", nil);
        } else if (error.errorCode == 0) {
            section.footerTitle = NSLocalizedString(@"_status_e2ee_on_server_", nil);
        } else {
            section.footerTitle = NSLocalizedString(@"_status_e2ee_not_setup_", nil);
        }
        [form addFormSection:section];
    
        // Start e2e
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"startE2E" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_e2e_settings_start_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(startE2E:);
        [section addFormRow:row];   
    }
    
    #ifdef DEBUG
    // Section DELETE KEYS -------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"Delete server keys ", nil)];
    [form addFormSection:section];
    
    // Delete publicKey
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"deleteCertificate" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"Delete certificate", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(deleteCertificate:);
    [section addFormRow:row];
    
    // Delete privateKey
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"deletePrivateKey" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"Delete PrivateKey", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(deletePrivateKey:);
    [section addFormRow:row];
    #endif
    
    self.tableView.showsVerticalScrollIndicator = NO;
    self.form = form;
}

// MARK: - View Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_e2e_settings_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
        
    // E2EE
    self.endToEndInitialize = [NCEndToEndInitialize new];
    self.endToEndInitialize.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:NCGlobal.shared.notificationCenterApplicationDidEnterBackground object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initialize) name:NCGlobal.shared.notificationCenterInitialize object:nil];

    [self initializeForm:nil];
    /*
    NKRequestOptions *options = [[NKRequestOptions alloc] initWithEndpoint:nil customHeader:nil customUserAgent:nil contentType:nil e2eToken: nil timeout:30 queue:dispatch_get_main_queue()];
    [[NextcloudKit shared] getE2EECertificateWithOptions:options completionHandler:^(NSString* account, NSString *certificate, NSData *data, NKError *error) {

    }];
    */
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    appDelegate.activeViewController = self;

    [[NCEndToEndInitialize alloc] statusOfServiceWithCompletion:^(NKError * error) {
        [self initializeForm:error];
    }];
}

#pragma mark - NotificationCenter

- (void)applicationDidEnterBackground
{
    if (passcodeViewController.view.window != nil) {
        [passcodeViewController dismissViewControllerAnimated:true completion:nil];
    }
}

- (void)initialize
{
    [[self navigationController] popViewControllerAnimated:YES];
}

#pragma mark - Action

- (void)startE2E:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];

    if ([[CCUtility getPasscode] length]) {
        
        [self passcodeType:@"startE2E"];
        
    } else {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_info_", nil) message:NSLocalizedString(@"_e2e_settings_lock_not_active_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        }];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)readPassphrase:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    if ([[CCUtility getPasscode] length]) {
        
        [self passcodeType:@"readPassphrase"];
        
    } else {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_info_", nil) message:NSLocalizedString(@"_e2e_settings_lock_not_active_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        }];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)removeLocallyEncryption:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    if ([[CCUtility getPasscode] length]) {
        
        [self passcodeType:@"removeLocallyEncryption"];
        
    } else {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_info_", nil) message:NSLocalizedString(@"_e2e_settings_lock_not_active_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        }];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

#pragma mark - Passcode -

- (void)passcodeType:(NSString *)type
{
    LAContext *laContext = [LAContext new];
    NSError *error;
    
    if ([[CCUtility getPasscode] length] > 0) {
        
        passcodeViewController = [[TOPasscodeViewController alloc] initPasscodeType:TOPasscodeTypeSixDigits allowCancel:true];
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
        
        // Type of passcode
        passcodeType = type;
        
        [self presentViewController:passcodeViewController animated:YES completion:nil];
    }
}

- (void)didTapCancelInPasscodeViewController:(TOPasscodeViewController *)passcodeViewController
{
    [passcodeViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)passcodeViewController:(TOPasscodeViewController *)passcodeViewController isCorrectCode:(NSString *)code
{
    if ([code isEqualToString:[CCUtility getPasscode]]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
            [self passcodeCorrectCode];
        });
        return YES;
    }
         
    return NO;
}

- (void)didPerformBiometricValidationRequestInPasscodeViewController:(TOPasscodeViewController *)passcodeViewController
{
    [[LAContext new] evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[[NCBrandOptions shared] brand] reply:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                [passcodeViewController dismissViewControllerAnimated:YES completion:nil];
                [self passcodeCorrectCode];
            });
        }
    }];
}

-(void)passcodeCorrectCode {
    
    if ([passcodeType isEqualToString:@"startE2E"]) {
        
        [self.endToEndInitialize initEndToEndEncryption];
        
    } else if ([passcodeType isEqualToString:@"readPassphrase"]) {
        
        NSString *e2ePassphrase = [CCUtility getEndToEndPassphrase:appDelegate.account];
        NSLog(@"[LOG] Passphrase: %@", e2ePassphrase);
        
        NSString *message = [NSString stringWithFormat:@"\n%@\n\n\n%@", NSLocalizedString(@"_e2e_settings_the_passphrase_is_", nil), e2ePassphrase];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_info_", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { }];
        UIAlertAction *copyPassphrase = [UIAlertAction actionWithTitle:NSLocalizedString(@"_copy_passphrase_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            UIPasteboard.generalPasteboard.string = e2ePassphrase;
        }];

        [alertController addAction:okAction];
        [alertController addAction:copyPassphrase];
        [self presentViewController:alertController animated:YES completion:nil];
        
    } else if ([passcodeType isEqualToString:@"removeLocallyEncryption"]) {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_e2e_settings_remove_", nil) message:NSLocalizedString(@"_e2e_settings_remove_message_", nil) preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_remove_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [CCUtility clearAllKeysEndToEnd:appDelegate.account];
            [self initializeForm:nil];
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}


- (void)deleteCertificate:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];

    NKRequestOptions *options = [[NKRequestOptions alloc] initWithEndpoint:nil customHeader:nil customUserAgent:nil contentType:nil e2eToken: nil timeout:60 queue:dispatch_get_main_queue()];
    [[NextcloudKit shared] deleteE2EECertificateWithOptions:options completionHandler:^(NSString *account, NKError *error) {
        if (error == NKError.success && [account isEqualToString:appDelegate.account]) {
            NKError *error = [[NKError alloc] initWithErrorCode:NCGlobal.shared.errorInternalError errorDescription:@"Success"];
             [[NCContentPresenter shared] messageNotification:@"E2E delete certificate" error:error delay:[[NCGlobal shared] dismissAfterSecond] type:messageTypeSuccess];
         } else {
             [[NCContentPresenter shared] messageNotification:@"E2E delete certificate" error:error  delay:[[NCGlobal shared] dismissAfterSecond] type:messageTypeError];
         }
    }];
}

- (void)deletePrivateKey:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];

    NKRequestOptions *options = [[NKRequestOptions alloc] initWithEndpoint:nil customHeader:nil customUserAgent:nil contentType:nil e2eToken: nil timeout:60 queue:dispatch_get_main_queue()];
    [[NextcloudKit shared] deleteE2EEPrivateKeyWithOptions: options completionHandler:^(NSString *account, NKError *error) {
        if (error == NKError.success && [account isEqualToString:appDelegate.account]) {
            NKError *error = [[NKError alloc] initWithErrorCode:NCGlobal.shared.errorInternalError errorDescription:@"Success"];
            [[NCContentPresenter shared] messageNotification:@"E2E delete privateKey" error:error delay:[[NCGlobal shared] dismissAfterSecond] type:messageTypeSuccess];
        } else {
            [[NCContentPresenter shared] messageNotification:@"E2E delete privateKey" error:error delay:[[NCGlobal shared] dismissAfterSecond] type:messageTypeError];
        }
    }];
}

#pragma mark - Delegate

- (void)endToEndInitializeSuccess
{
    // Reload All Datasource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCGlobal.shared.notificationCenterReloadDataSource object:nil];

    [self initializeForm:nil];
}

#pragma mark -

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NCGlobal.shared.heightCellSettings;
}

@end

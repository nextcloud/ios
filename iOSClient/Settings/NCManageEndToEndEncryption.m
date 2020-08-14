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
#import "AppDelegate.h"
#import <TOPasscodeViewController/TOPasscodeViewController.h>

#import "NCBridgeSwift.h"

@interface NCManageEndToEndEncryption () <NCEndToEndInitializeDelegate, TOPasscodeViewControllerDelegate>
{
    AppDelegate *appDelegate;
    NSString *passcodeType;
    TOPasscodeViewController *passcodeViewController;
}
@end

@implementation NCManageEndToEndEncryption

- (void)initializeForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    BOOL isE2EEEnabled = [[NCManageDatabase sharedInstance] getCapabilitiesServerBoolWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesE2EEEnabled exists:false];
    NSString *versionE2EE = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:appDelegate.account elements:NCElementsJSON.shared.capabilitiesE2EEApiVersion];
    
    if (![versionE2EE isEqual:k_E2EE_API] && isE2EEEnabled) {
        [[NCContentPresenter shared] messageNotification:@"_error_e2ee_" description:@"_err_e2ee_app_version_" delay:k_dismissAfterSecond type:messageTypeError errorCode:k_CCErrorInternalError forced:true];
    }
    
    if (isE2EEEnabled == NO || ![versionE2EE isEqual:k_E2EE_API]) {
        
        // Section SERVICE NOT AVAILABLE -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSection];
        if (isE2EEEnabled) {
            section.footerTitle = [NSString stringWithFormat:@"End-to-End Encryption %@", versionE2EE];
        }
        [form addFormSection:section];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"serviceActivated" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_e2e_settings_not_available_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"closeCircle"] width:50 height:50 color:[UIColor redColor]] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [section addFormRow:row];
        
        self.tableView.showsVerticalScrollIndicator = NO;
        self.form = form;

        return;
    }
    
    if ([CCUtility isEndToEndEnabled:appDelegate.account]) {
        
        // Section SERVICE ACTIVATED -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSection];
        section.footerTitle = [NSString stringWithFormat:@"End-to-End Encryption %@", versionE2EE];
        [form addFormSection:section];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"serviceActivated" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_e2e_settings_activated_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"selectFull"] width:50 height:50 color:[UIColor greenColor]] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [section addFormRow:row];
        
        // Section PASSPHRASE -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        // Read Passphrase
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"readPassphrase" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_e2e_settings_read_passphrase_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"e2eReadPassphrase"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(readPassphrase:);
        [section addFormRow:row];
        
        // Section DELETE -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        // remove locally Encryption
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"removeLocallyEncryption" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_e2e_settings_remove_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"lock"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(removeLocallyEncryption:);
        [section addFormRow:row];
        
    } else {
        
        // Section START E2E -------------------------------------------------

        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
    
        // Start e2e
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"startE2E" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_e2e_settings_start_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(startE2E:);
        [section addFormRow:row];   
    }
    
    #ifdef DEBUG
    // Section DELETE KEYS -------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"Delete server keys ", nil)];
    [form addFormSection:section];
    
    // Delete publicKey
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"deletePublicKey" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"Delete PublicKey", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(deletePublicKey:);
    [section addFormRow:row];
    
    // Delete privateKey
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"deletePrivateKey" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"Delete PrivateKey", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(deletePrivateKey:);
    [section addFormRow:row];
    #endif
    
    self.tableView.showsVerticalScrollIndicator = NO;
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_e2e_settings_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        
    // E2EE
    self.endToEndInitialize = [NCEndToEndInitialize new];
    self.endToEndInitialize.delegate = self;
    
    // changeTheming
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:k_notificationCenter_changeTheming object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:k_notificationCenter_applicationDidEnterBackground object:nil];

    [self changeTheming];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:self.tableView collectionView:nil form:true];
    [self initializeForm];
}

- (void)applicationDidEnterBackground
{
    if (passcodeViewController.view.window != nil) {
        [passcodeViewController dismissViewControllerAnimated:true completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Action ===
#pragma --------------------------------------------------------------------------------------------

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
        
        passcodeViewController = [[TOPasscodeViewController alloc] initWithStyle:TOPasscodeViewStyleTranslucentLight passcodeType:TOPasscodeTypeSixDigits];
        if (@available(iOS 13.0, *)) {
            if ([[UITraitCollection currentTraitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark) {
                passcodeViewController.style = TOPasscodeViewStyleTranslucentDark;
            }
        }
    
        passcodeViewController.delegate = self;
        passcodeViewController.allowCancel = true;
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
    [[LAContext new] evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:[[NCBrandOptions sharedInstance] brand] reply:^(BOOL success, NSError * _Nullable error) {
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
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { }];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
        
    } else if ([passcodeType isEqualToString:@"removeLocallyEncryption"]) {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_e2e_settings_remove_", nil) message:NSLocalizedString(@"_e2e_settings_remove_message_", nil) preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_remove_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [CCUtility clearAllKeysEndToEnd:appDelegate.account];
            [self initializeForm];
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}


- (void)deletePublicKey:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [[NCCommunication shared] deleteE2EEPublicKeyWithCustomUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSInteger errorCode, NSString *errorDescription) {
       if (errorCode == 0 && [account isEqualToString:appDelegate.account]) {
            [[NCContentPresenter shared] messageNotification:@"E2E delete publicKey" description:@"Success" delay:k_dismissAfterSecond type:messageTypeSuccess errorCode:k_CCErrorInternalError forced:true];
        } else {
            [[NCContentPresenter shared] messageNotification:@"E2E delete publicKey" description:errorDescription  delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode forced:true];
        }
    }];
}

- (void)deletePrivateKey:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [[NCCommunication shared] deleteE2EEPrivateKeyWithCustomUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSInteger errorCode, NSString *errorDescription) {
        if (errorCode == 0 && [account isEqualToString:appDelegate.account]) {
            [[NCContentPresenter shared] messageNotification:@"E2E delete privateKey" description:@"Success" delay:k_dismissAfterSecond type:messageTypeSuccess errorCode:k_CCErrorInternalError forced:true];
        } else {
            [[NCContentPresenter shared] messageNotification:@"E2E delete privateKey" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode forced:true];
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delegate ===
#pragma --------------------------------------------------------------------------------------------

- (void)endToEndInitializeSuccess
{
    // Reload All Datasource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_reloadDataSource object:nil];

    [self initializeForm];
}

@end

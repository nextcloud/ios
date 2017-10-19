//
//  NCManageEndToEndEncryption.m
//  Nextcloud
//
//  Created by Marino Faggiana on 13/10/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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
#import "CCNetworking.h"

#import "NCBridgeSwift.h"

@interface NCManageEndToEndEncryption ()
{
    NSUInteger _failedAttempts;
    NSDate *_lockUntilDate;
}
@end

@implementation NCManageEndToEndEncryption

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadForm) name:@"reloadManageEndToEndEncryption" object:nil];
        [self initializeForm];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadForm) name:@"reloadManageEndToEndEncryption" object:nil];
        [self initializeForm];
    }
    return self;
}

- (void)initializeForm
{
    XLFormDescriptor *form ;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_e2e_settings_", nil)];
    
    tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilites];

    if (capabilities.endToEndEncryption == NO) {
        
        // Section SERVICE NOT AVAILABLE -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"serviceActivated" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_e2e_settings_not_available_", nil)];
        [row.cellConfig setObject:[UIImage imageNamed:@"no_red"] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [section addFormRow:row];
        
        self.form = form;

        return;
    }
    
    if ([CCUtility isEndToEndEnabled:app.activeAccount]) {
        
        // Section SERVICE ACTIVATED -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"serviceActivated" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_e2e_settings_activated_", nil)];
        [row.cellConfig setObject:[UIImage imageNamed:@"ok_green"] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [section addFormRow:row];
        
        // Section PASSPHRASE -------------------------------------------------
        
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_e2e_settings_read_passphrase_", nil)];
        [form addFormSection:section];
        
        // Read Passphrase
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"readPassphrase" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_e2e_settings_read_passphrase_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(readPassphrase:);
        [section addFormRow:row];
        
    } else {
        
        // Section START E2E -------------------------------------------------

        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
    
        // Start e2e
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"startE2E" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_e2e_settings_start_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
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
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(deletePublicKey:);
    [section addFormRow:row];
    
    // Delete privateKey
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"deletePrivateKey" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"Delete PrivateKey", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(deletePrivateKey:);
    [section addFormRow:row];
    
    // Delete locally Encryption
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"deleteLocallyEncryption" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"Delete locally encryption", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(deleteLocallyEncryption:);
    [section addFormRow:row];
    
#endif
    
    self.form = form;
}

-(void)reloadForm
{
    [self initializeForm];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Action ===
#pragma --------------------------------------------------------------------------------------------

- (void)deletePublicKey:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionDeleteEndToEndPublicKey;
    [app addNetworkingOperationQueue:app.netQueue delegate:app.endToEndInterface metadataNet:metadataNet];
}

- (void)deletePrivateKey:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];

    metadataNet.action = actionDeleteEndToEndPrivateKey;
    [app addNetworkingOperationQueue:app.netQueue delegate:app.endToEndInterface metadataNet:metadataNet];
}

- (void)deleteLocallyEncryption:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [CCUtility initEndToEnd:app.activeAccount];
    
    [self initializeForm];
}

- (void)startE2E:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];

    [CCUtility initEndToEnd:app.activeAccount];
    [app.endToEndInterface initEndToEndEncryption];
}

- (void)readPassphrase:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    if ([[CCUtility getBlockCode] length]) {
        
        CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
        viewController.delegate = self;
        viewController.fromType = CCBKPasscodeFromCheckPassphrase;
        viewController.type = BKPasscodeViewControllerCheckPasscodeType;
            
        if ([CCUtility getSimplyBlockCode]) {
            viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 6;
        } else {
            viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 64;
        }
        
        BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
        touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
        viewController.touchIDManager = touchIDManager;
        
        viewController.title = NSLocalizedString(@"_e2e_settings_read_passphrase_", nil);
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].encrypted;
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [self presentViewController:navigationController animated:YES completion:nil];
        
    } else {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_info_", nil) message:NSLocalizedString(@"_e2e_settings_lock_not_active_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        }];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === BKPasscodeViewController ===
#pragma --------------------------------------------------------------------------------------------

- (NSUInteger)passcodeViewControllerNumberOfFailedAttempts:(CCBKPasscode *)aViewController
{
    return _failedAttempts;
}

- (NSDate *)passcodeViewControllerLockUntilDate:(CCBKPasscode *)aViewController
{
    return _lockUntilDate;
}

- (void)passcodeViewCloseButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if ([aPasscode isEqualToString:[CCUtility getBlockCode]]) {
        _lockUntilDate = nil;
        _failedAttempts = 0;
        aResultHandler(YES);
    } else
        aResultHandler(NO);
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    [aViewController dismissViewControllerAnimated:YES completion:nil];
    
    NSString *e2ePassphrase = [CCUtility getEndToEndPassphrase:app.activeAccount];
    NSLog(@"Passphrase: %@", e2ePassphrase);
    
    NSString *message = [NSString stringWithFormat:@"\n%@\n\n\n%@", NSLocalizedString(@"_e2e_settings_the_passphrase_is_", nil), e2ePassphrase];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_info_", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end

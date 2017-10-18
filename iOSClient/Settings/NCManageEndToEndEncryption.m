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
#import "NYMnemonic.h"
#import "NCBridgeSwift.h"

@implementation NCManageEndToEndEncryption

-(id)init
{
    XLFormDescriptor *form ;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_e2e_settings_encryption_", nil)];
    
    tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilites];

    if (capabilities.endToEndEncryption == NO) {
        
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_e2e_settings_encryption_not_available_", nil)];
        [form addFormSection:section];
        
        return [super initWithForm:form];
    }
    
    
    // Section INITIALIZE -------------------------------------------------

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_e2e_settings_encryption_initialize_", nil)];
    [form addFormSection:section];
    
    // Inizializze e2e
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"initE2E" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_e2e_settings_encryption_initialize_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(initE2E:);
    [section addFormRow:row];
    
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
#endif
    
    return [super initWithForm:form];
}

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

- (void)initE2E:(XLFormRowDescriptor *)sender
{
    NSString *message;
 
    [self deselectFormRow:sender];

    // select Passphrase
    //app.e2ePassphrase = k_passphrase_test;
    app.e2ePassphrase = [NYMnemonic generateMnemonicString:@128 language:@"english"];
    
    if ([CCUtility isEndToEndEnabled:app.activeAccount]) {
        
        message = [NSString stringWithFormat:@"%@\n\n%@\n\n%@", NSLocalizedString(@"_e2e_settings_encryption_initialize_already_request_", nil), NSLocalizedString(@"_e2e_settings_encryption_view_passphrase_", nil), app.e2ePassphrase];

    } else {

        message = [NSString stringWithFormat:@"%@\n\n%@\n\n%@", NSLocalizedString(@"_e2e_settings_encryption_initialize_request_", nil), NSLocalizedString(@"_e2e_settings_encryption_view_passphrase_", nil), app.e2ePassphrase];
    }
        
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_initialization_", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        NSLog(@"Cancel action");
    }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        [self deletePublicKey:sender];
        [self deletePrivateKey:sender];
        
        [CCUtility initEndToEnd:app.activeAccount];
    }];
    
    [alertController addAction:cancelAction];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end

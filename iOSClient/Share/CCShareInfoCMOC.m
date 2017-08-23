//
//  CCShareInfoCMOC.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 07/03/16.
//  Copyright (c) 2017 TWS. All rights reserved.
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

#import "CCShareInfoCMOC.h"
#import "XLFormViewController.h"
#import "XLForm.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface CCShareInfoCMOC ()

@end

/*
 #define k_permission_shared @"S"
 #define k_permission_can_share @"R"
 #define k_permission_mounted @"M"
 #define k_permission_file_can_write @"W"
 #define k_permission_can_create_file @"C"
 #define k_permission_can_create_folder @"K"
 #define k_permission_can_delete @"D"
 #define k_permission_can_rename @"N"
 #define k_permission_can_move @"V"
*/

@implementation CCShareInfoCMOC

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
                
    }
    return self;
}

- (void)initializeForm
{
    XLFormDescriptor *form ;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    form = [XLFormDescriptor formDescriptor];
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_share_permission_title_", nil)];
    [form addFormSection:section];
    
    if (self.metadata.directory == NO) {
    
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"edit" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_file_can_write_", nil)];
        if ([self.metadata.permissions rangeOfString:k_permission_file_can_write].location != NSNotFound) row.value = @1;
        else row.value = @0;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
        [section addFormRow:row];
    }
    
    if (self.metadata.directory == YES) {
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"createfile" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_create_file_", nil)];
        if ([self.metadata.permissions rangeOfString:k_permission_can_create_file].location != NSNotFound) row.value = @1;
        else row.value = @0;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
        [section addFormRow:row];
    
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"createfolder" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_create_folder_", nil)];
        if ([self.metadata.permissions rangeOfString:k_permission_can_create_folder].location != NSNotFound) row.value = @1;
        else row.value = @0;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
        [section addFormRow:row];
    }
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"delete" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_delete_", nil)];
    if ([self.metadata.permissions rangeOfString:k_permission_can_delete].location != NSNotFound) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"rename" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_rename_", nil)];
    if ([self.metadata.permissions rangeOfString:k_permission_can_rename].location != NSNotFound) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"move" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_move_", nil)];
    if ([self.metadata.permissions rangeOfString:k_permission_can_move].location != NSNotFound) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"share" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_share_", nil)];
    if ([self.metadata.permissions rangeOfString:k_permission_can_share].location != NSNotFound) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_share_permission_info_", nil)];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sharetype" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_share_permission_type_", nil)];
    
    if ([self.metadata.permissions rangeOfString:k_permission_shared].location != NSNotFound) row.value = NSLocalizedString(@"_type_resource_connect_you_", nil);
    if ([self.metadata.permissions rangeOfString:k_permission_mounted].location != NSNotFound) row.value = NSLocalizedString(@"_type_resource_external_", nil);
    
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    self.form = form;
    
    form.disabled = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [NCBrandColor sharedInstance].tableBackground;
    
    [self.endButton setTitle:NSLocalizedString(@"_done_", nil) forState:UIControlStateNormal];
    self.endButton.tintColor = [NCBrandColor sharedInstance].brand;
    
    self.tableView.backgroundColor = [NCBrandColor sharedInstance].tableBackground;
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    metadataNet.action = actionGetSharePermissionsFile;
    metadataNet.fileName = _metadata.fileNameData;
    metadataNet.serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];

    [self initializeForm];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delegate getSharePermissions =====
#pragma --------------------------------------------------------------------------------------------

- (void)getSharePermissionsFileSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions
{
    // ----------------------
    
    XLFormRowDescriptor *rowEdit = [self.form formRowWithTag:@"edit"];
    XLFormRowDescriptor *rowCreateFile = [self.form formRowWithTag:@"createfile"];
    XLFormRowDescriptor *rowCreateFolder = [self.form formRowWithTag:@"createfolder"];
    XLFormRowDescriptor *rowDelete = [self.form formRowWithTag:@"delete"];
    XLFormRowDescriptor *rowRename = [self.form formRowWithTag:@"rename"];
    XLFormRowDescriptor *rowMove = [self.form formRowWithTag:@"move"];
    XLFormRowDescriptor *rowShare = [self.form formRowWithTag:@"share"];
    
    // ------------------------------------------------------------------
    
    if (self.metadata.directory == NO) {
        
        
    } else {
        
    }
    
    
    /*
    if ([[CCUtility getBlockCode] length]) {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[UIImage imageNamed:@"settingsPasscodeYES"] forKey:@"imageView.image"];
    } else {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_not_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[UIImage imageNamed:@"settingsPasscodeNO"] forKey:@"imageView.image"];
    }
    
    if ([CCUtility getSimplyBlockCode]) [rowSimplyPasscode setValue:@1]; else [rowSimplyPasscode setValue:@0];
    if ([CCUtility getOnlyLockDir]) [rowOnlyLockDir setValue:@1]; else [rowOnlyLockDir setValue:@0];
    if ([CCUtility getFavoriteOffline]) [rowFavoriteOffline setValue:@1]; else [rowFavoriteOffline setValue:@0];
    */
    
    // -----------------------------------------------------------------
    
    [self.tableView reloadData];
}

- (void)getSharePermissionsFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;
{
    [app messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Button =====
#pragma --------------------------------------------------------------------------------------------

- (IBAction)endButtonAction:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

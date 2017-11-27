//
//  CCShareInfoCMOC.m
//  Nextcloud iOS
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
#import "CCHud.h"
#import "NCBridgeSwift.h"

@interface CCShareInfoCMOC ()
{
    AppDelegate *appDelegate;
    CCHud *_hud;
}
@end

/*
const PERMISSION_CREATE = 4;
const PERMISSION_READ = 1;
const PERMISSION_UPDATE = 2;
const PERMISSION_DELETE = 8;
const PERMISSION_SHARE = 16;
const PERMISSION_ALL = 31;
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
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"create" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_create_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"read" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_read_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"change" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_change_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"delete" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_delete_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"share" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_share_", nil)];
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
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    self.view.backgroundColor = [NCBrandColor sharedInstance].backgroundView;
    
    [self.endButton setTitle:NSLocalizedString(@"_done_", nil) forState:UIControlStateNormal];
    self.endButton.tintColor = [NCBrandColor sharedInstance].brand;
    
    self.tableView.backgroundColor = [NCBrandColor sharedInstance].backgroundView;
    
    _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    [_hud visibleHudTitle:@"" mode:MBProgressHUDModeIndeterminate color:nil];
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
    metadataNet.action = actionGetSharePermissionsFile;
    metadataNet.fileName = _metadata.fileName;
    metadataNet.serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];

    [self initializeForm];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delegate getSharePermissions =====
#pragma --------------------------------------------------------------------------------------------

- (void)getSharePermissionsFileSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions
{
    [_hud hideHud];

    if (permissions == nil)
        return;
    
    NSInteger iPermissions = [permissions integerValue];

    // ------------------------------------------------------------------
    
    XLFormRowDescriptor *rowCreate = [self.form formRowWithTag:@"create"];
    XLFormRowDescriptor *rowRead = [self.form formRowWithTag:@"read"];
    XLFormRowDescriptor *rowChange = [self.form formRowWithTag:@"change"];
    XLFormRowDescriptor *rowDelete = [self.form formRowWithTag:@"delete"];
    XLFormRowDescriptor *rowShare = [self.form formRowWithTag:@"share"];
    
    // ------------------------------------------------------------------
    
    if ([UtilsFramework isPermissionToCanCreate:iPermissions]) rowCreate.value = @1;
    else rowCreate.value = @0;
        
    if ([UtilsFramework isPermissionToRead:iPermissions]) rowRead.value = @1;
    else rowRead.value = @0;

    if ([UtilsFramework isPermissionToCanChange:iPermissions]) rowChange.value = @1;
    else rowChange.value = @0;

    if ([UtilsFramework isPermissionToCanDelete:iPermissions]) rowDelete.value = @1;
    else rowDelete.value = @0;

    if ([UtilsFramework isPermissionToCanShare:iPermissions]) rowShare.value = @1;
    else rowShare.value = @0;

    // -----------------------------------------------------------------
    
    [self.tableView reloadData];
}

- (void)getSharePermissionsFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode;
{
    [_hud hideHud];

    [appDelegate messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    
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

//
//  CCSharePermissionOC.m
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

#import "CCSharePermissionOC.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface CCSharePermissionOC ()
{
    OCSharedDto *shareDto;
}
@end

@implementation CCSharePermissionOC

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
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"edit" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_edit_", nil)];
    if ([UtilsFramework isAnyPermissionToEdit:shareDto.permissions]) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];
    
    if (shareDto.isDirectory) {
    
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"create" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_create_", nil)];
        row.hidden = [NSString stringWithFormat:@"$%@==0", @"edit"];
        if ([UtilsFramework isPermissionToCanCreate:shareDto.permissions]) row.value = @1;
        else row.value = @0;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
        [section addFormRow:row];
    
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"change" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_change_", nil)];
        row.hidden = [NSString stringWithFormat:@"$%@==0", @"edit"];
        if ([UtilsFramework isPermissionToCanChange:shareDto.permissions]) row.value = @1;
        else row.value = @0;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
        [section addFormRow:row];
    
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"delete" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_delete_", nil)];
        row.hidden = [NSString stringWithFormat:@"$%@==0", @"edit"];
        if ([UtilsFramework isPermissionToCanDelete:shareDto.permissions]) row.value = @1;
        else row.value = @0;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
        [section addFormRow:row];
    }
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"share" rowType:XLFormRowDescriptorTypeBooleanCheck title:NSLocalizedString(@"_share_permission_share_", nil)];
    if ([UtilsFramework isPermissionToCanShare:shareDto.permissions]) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"tintColor"];
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_share_permission_info_", nil)];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sharepath" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_share_permission_path_", nil)];
    row.value = self.metadata.fileNamePrint;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sharetype" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_share_permission_type_", nil)];
    if (shareDto.shareType == shareTypeUser) row.value = NSLocalizedString(@"_share_permission_typeuser_", nil);
    if (shareDto.shareType == shareTypeGroup) row.value = NSLocalizedString(@"_share_permission_typegroup_", nil);
    if (shareDto.shareType == shareTypeLink) row.value = NSLocalizedString(@"_share_permission_typepubliclink_", nil);
    if (shareDto.shareType == shareTypeRemote) row.value = NSLocalizedString(@"_share_permission_typefederated_", nil);
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"shareowner" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_share_permission_owner_", nil)];
    row.value = shareDto.displayNameOwner;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sharedate" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_share_permission_date_", nil)];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:shareDto.sharedDate];
    row.value = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sharemail" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_share_permission_email_", nil)];
    if (shareDto.mailSend == 0) row.value = NSLocalizedString(@"_no_", nil);
    if (shareDto.mailSend == 1) row.value = NSLocalizedString(@"_yes_", nil);
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];

    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [NCBrandColor sharedInstance].tableBackground;
    
    [self.endButton setTitle:NSLocalizedString(@"_done_", nil) forState:UIControlStateNormal];
    self.endButton.tintColor = [NCBrandColor sharedInstance].brand;
    
    self.tableView.backgroundColor = [NCBrandColor sharedInstance].tableBackground;
    
    shareDto = [app.sharesID objectForKey:self.idRemoteShared];
        
    [self initializeForm];    
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Button =====
#pragma --------------------------------------------------------------------------------------------

- (IBAction)endButtonAction:(id)sender
{
    NSInteger permission;
    
    XLFormRowDescriptor *rowEdit = [self.form formRowWithTag:@"edit"];
    XLFormRowDescriptor *rowCreate = [self.form formRowWithTag:@"create"];
    XLFormRowDescriptor *rowChange = [self.form formRowWithTag:@"change"];
    XLFormRowDescriptor *rowDelete = [self.form formRowWithTag:@"delete"];
    XLFormRowDescriptor *rowShare = [self.form formRowWithTag:@"share"];
    
    if ([rowEdit.value boolValue] == 0) 
        permission = [UtilsFramework getPermissionsValueByCanEdit:NO andCanCreate:NO andCanChange:NO andCanDelete:NO andCanShare:[rowShare.value boolValue] andIsFolder:shareDto.isDirectory];
    else
        permission = [UtilsFramework getPermissionsValueByCanEdit:[rowEdit.value boolValue] andCanCreate:[rowCreate.value boolValue] andCanChange:[rowChange.value boolValue] andCanDelete:[rowDelete.value boolValue] andCanShare:[rowShare.value boolValue] andIsFolder:shareDto.isDirectory];
    
    if (permission != shareDto.permissions)
        [self.delegate updateShare:self.idRemoteShared metadata:self.metadata serverUrl:self.serverUrl password:nil expirationTime:nil permission:permission];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

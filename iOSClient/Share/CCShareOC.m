//
//  CCShareOC.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 13/11/15.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
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

#import "CCShareOC.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface CCShareOC ()
{
    AppDelegate *appDelegate;
    tableCapabilities *capabilities;
}
@end

@implementation CCShareOC

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        self.itemsShareWith = [[NSMutableArray alloc] init];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDatasource) name:@"ShareReloadDatasource" object:nil];

        [self initializeForm];
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
    
    // Share Link
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_share_link_", nil)];
    [form addFormSection:section];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"shareLinkSwitch" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_share_link_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"shareLinkPermission" rowType:XLFormRowDescriptorTypePicker];
    row.height = 70;
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"password" rowType:XLFormRowDescriptorTypePassword title:NSLocalizedString(@"_password_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
 
    capabilities = [[NCManageDatabase sharedInstance] getCapabilitesWithAccount:appDelegate.activeAccount];
    if (capabilities != nil && capabilities.versionMajor >= k_nextcloud_version_15_0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"hideDownload" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_share_link_hide_download_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [section addFormRow:row];
    }
        
    // Expiration date
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"expirationDate" rowType:XLFormRowDescriptorTypeDate title:NSLocalizedString(@"_date_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    row.value = [self tomorrow];
    [row.cellConfigAtConfigure setObject:[self tomorrow] forKey:@"minimumDate"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"expirationDateSwitch" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_share_expirationdate_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    // Send Link To
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sendLinkTo" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_share_link_button_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    row.action.formSelector = @selector(sendLinkTo:);
    [section addFormRow:row];

    // Sharee
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_share_title_", nil)];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_add_sharee_footer_", nil);
        
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"findUser" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_add_sharee_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    row.action.formSelector = @selector(shareUserButton:);
    [section addFormRow:row];
        
    section = [XLFormSectionDescriptor formSectionWithTitle:@"" sectionOptions:XLFormSectionOptionCanDelete];
    [form addFormSection:section];
    
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [NCBrandColor sharedInstance].backgroundView;
    
    [self.endButton setTitle:NSLocalizedString(@"_done_", nil) forState:UIControlStateNormal];
    self.endButton.tintColor = [UIColor blackColor];
    
    [self reloadDatasource];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:self.metadata.fileID fileNameView:self.metadata.fileNameView]]) {
        
        self.fileImageView.image = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:self.metadata.fileID fileNameView:self.metadata.fileNameView]];
        
    } else {
        
        if (self.metadata.directory)
            self.fileImageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement];
        else
            self.fileImageView.image = [UIImage imageNamed:self.metadata.iconName];

    }
    
    self.labelTitle.text = self.metadata.fileNameView;
    self.labelTitle.textColor = [UIColor blackColor];
    
    self.tableView.tableHeaderView = ({UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 0.1 / UIScreen.mainScreen.scale)];
        line.backgroundColor = self.tableView.separatorColor;
        line;
    });
    
    self.tableView.backgroundColor = [NCBrandColor sharedInstance].backgroundView;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Networking =====
#pragma --------------------------------------------------------------------------------------------

- (void)share:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password permission:(NSInteger)permission hideDownload:(BOOL)hideDownload
{
    NSString *fileName = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:serverUrl activeUrl:appDelegate.activeUrl];
    
    [[OCNetworking sharedManager] shareWithAccount:appDelegate.activeAccount fileName:fileName password:password permission:permission hideDownload:hideDownload completion:^(NSString *account, NSString *message, NSInteger errorCode) {
        
        if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
            
        } else if (errorCode != 0) {
            
            [appDelegate messageNotification:@"_share_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
        }
        
        [self reloadDatasource];
    }];
}

- (void)unShare:(NSString *)share metadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl
{
    [[OCNetworking sharedManager] unshareAccount:appDelegate.activeAccount shareID:[share integerValue] completion:^(NSString *account, NSString *message, NSInteger errorCode) {
        
        if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
            
            // rimuoviamo la condivisione da db
            NSArray *result = [[NCManageDatabase sharedInstance] unShare:share fileName:metadata.fileName serverUrl:metadata.serverUrl sharesLink:appDelegate.sharesLink sharesUserAndGroup:appDelegate.sharesUserAndGroup account:account];
            
            if (result) {
                appDelegate.sharesLink = result[0];
                appDelegate.sharesUserAndGroup = result[1];
            }
            
        } else if (errorCode != 0) {
            
            [appDelegate messageNotification:@"_share_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
        }
        
        [self reloadDatasource];
    }];
}

- (void)updateShare:(NSString *)share metadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password expirationTime:(NSString *)expirationTime permission:(NSInteger)permission hideDownload:(BOOL)hideDownload
{
    [[OCNetworking sharedManager] shareUpdateAccount:appDelegate.activeAccount shareID:[share integerValue] password:password permission:permission expirationTime:expirationTime hideDownload:hideDownload completion:^(NSString *account, NSString *message, NSInteger errorCode) {
        
        if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
            
        } else if (errorCode != 0) {
            
            [appDelegate messageNotification:@"_share_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
        }
        
        [self reloadDatasource];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Reload Data =====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasource
{    
    // bugfix
    if (!self.serverUrl || !self.metadata) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self.delegate readShareServer];
            [self dismissViewControllerAnimated:YES completion:nil];
        });
        
        return;
    }
    
    NSString *path = [CCUtility returnFileNamePathFromFileName:self.metadata.fileName serverUrl:self.serverUrl activeUrl:appDelegate.activeUrl];

    [[OCNetworking sharedManager] readShareWithAccount:appDelegate.activeAccount path:path completion:^(NSString *account, NSArray *items, NSString *message, NSInteger errorCode) {
        
        NSLog(@"x");
    }];
    
    return;
    
    self.shareLink = [appDelegate.sharesLink objectForKey:[self.serverUrl stringByAppendingString:self.metadata.fileName]];
    self.shareUserAndGroup = [appDelegate.sharesUserAndGroup objectForKey:[self.serverUrl stringByAppendingString:self.metadata.fileName]];

    self.itemShareLink = [appDelegate.sharesID objectForKey:self.shareLink];
    if ([self.shareUserAndGroup length] > 0) self.itemsUserAndGroupLink = [self.shareUserAndGroup componentsSeparatedByString:@","];
    else self.itemsUserAndGroupLink = nil;

    self.form.delegate = nil;

    XLFormRowDescriptor *rowShareLinkSwitch = [self.form formRowWithTag:@"shareLinkSwitch"];
    XLFormRowDescriptor *rowShareLinkPermission = [self.form formRowWithTag:@"shareLinkPermission"];
    XLFormRowDescriptor *rowPassword = [self.form formRowWithTag:@"password"];
    XLFormRowDescriptor *rowHideDownload = [self.form formRowWithTag:@"hideDownload"];
    
    XLFormRowDescriptor *rowExpirationDate = [self.form formRowWithTag:@"expirationDate"];
    XLFormRowDescriptor *rowExpirationDateSwitch = [self.form formRowWithTag:@"expirationDateSwitch"];
    
    XLFormRowDescriptor *rowSendLinkTo = [self.form formRowWithTag:@"sendLinkTo"];
    
    XLFormRowDescriptor *rowFindUser = [self.form formRowWithTag:@"findUser"];

    // Share Link
    if ([self.shareLink length] > 0) {
        
        [rowShareLinkSwitch setValue:@1];
        
        rowShareLinkPermission.disabled = @NO;
        rowPassword.disabled = @NO;
        rowHideDownload.disabled = @NO;
        rowExpirationDate.disabled = @NO;
        rowExpirationDateSwitch.disabled = @NO;
        
        rowSendLinkTo.disabled = @NO;
        
    } else {
        
        [rowShareLinkSwitch setValue:@0];
        
        rowShareLinkPermission.disabled = @YES;
        rowPassword.disabled = @YES;
        rowHideDownload.disabled = @YES;
        rowExpirationDate.disabled = @YES;
        rowExpirationDateSwitch.disabled = @YES;
        
        rowSendLinkTo.disabled = @YES;
    }
    
    // Permission
    if (self.metadata.directory) {
        rowShareLinkPermission.selectorOptions = @[NSLocalizedString(@"_share_link_readonly_", nil), NSLocalizedString(@"_share_link_upload_modify_", nil), NSLocalizedString(@"_share_link_upload_", nil)];
    } else {
        rowShareLinkPermission.selectorOptions = @[NSLocalizedString(@"_share_link_readonly_", nil), NSLocalizedString(@"_share_link_modify_", nil)];
    }
    if (self.itemShareLink.permissions > 0 && self.itemShareLink.shareType == shareTypeLink) {
        switch (self.itemShareLink.permissions) {
            case 1:
                rowShareLinkPermission.value = NSLocalizedString(@"_share_link_readonly_", nil);
                break;
            case 3:
                rowShareLinkPermission.value = NSLocalizedString(@"_share_link_modify_", nil);
                break;
            case 4:
                rowShareLinkPermission.value = NSLocalizedString(@"_share_link_upload_", nil);
                break;
            case 15:
                rowShareLinkPermission.value = NSLocalizedString(@"_share_link_upload_modify_", nil);
                break;
            default:
                break;
        }
    } else {
        rowShareLinkPermission.value = NSLocalizedString(@"_share_link_readonly_", nil);
    }
    
    // Password
    if ([[self.itemShareLink shareWith] length] > 0 && self.itemShareLink.shareType == shareTypeLink)
        rowPassword.value = [self.itemShareLink shareWith];
    else
        rowPassword.value = @"";
    
    // Hide Download
    if (self.itemShareLink.hideDownload) rowHideDownload.value = @1;
    else rowHideDownload.value = @0;
    
    // Expiration Date
    if (self.itemShareLink.expirationDate) {
        
        rowExpirationDateSwitch.value = @1;
        NSDate *expireDate;
        
        if (self.itemShareLink.expirationDate) expireDate = [NSDate dateWithTimeIntervalSince1970: self.itemShareLink.expirationDate];
        else expireDate = [self tomorrow];
        
        rowExpirationDate.value = expireDate;
        
    } else {
        
        rowExpirationDateSwitch.value = @0;
        rowExpirationDate.value = [self tomorrow];
    }
    
    // User & Group
    XLFormSectionDescriptor *section = [self.form formSectionAtIndex:4];
    [section.formRows removeAllObjects];
    [self.itemsShareWith removeAllObjects];
    
    if ([self.itemsUserAndGroupLink count] > 0) {
    
        for (NSString *idRemoteShared in self.itemsUserAndGroupLink) {
            
            OCSharedDto *item = [appDelegate.sharesID objectForKey:idRemoteShared];
            
            XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:idRemoteShared rowType:XLFormRowDescriptorTypeButton];

            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
            //[row.cellConfig setObject:@(UITableViewCellAccessoryDisclosureIndicator) forKey:@"accessoryType"];
            [row.cellConfig setObject:[NCBrandColor sharedInstance].brandElement forKey:@"textLabel.textColor"];
            row.action.formSelector = @selector(sharePermissionButton:);
                
            if (item.shareType == shareTypeGroup) row.title = [item.shareWithDisplayName stringByAppendingString:NSLocalizedString(@"_user_is_group_", nil)];
            else row.title = item.shareWithDisplayName;
            
            //If the initiator or the recipient is not the current user, show the list of sharees without any options to edit it.
            if (![item.uidOwner isEqualToString:appDelegate.activeUserID] && ![item.uidFileOwner isEqualToString:appDelegate.activeUserID]) {
                row.disabled = @YES;
            }
            
            [section addFormRow:row];
                
            // add users
            [self.itemsShareWith addObject:item];
            
            // shared with you by
            if (![item.uidFileOwner isEqualToString:appDelegate.activeUserID]) {
                self.labelSharedWithYouBy.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"_shared_with_you_by_", nil), item.displayNameFileOwner];
            }
        }
            
        section.footerTitle = NSLocalizedString(@"_user_sharee_footer_", nil);

    } else {
            
        section.footerTitle = @"";
    }
    
    // canShare
    BOOL canShare = [self.metadata.permissions containsString:k_permission_can_share];
    if (! canShare) {
        
        rowShareLinkSwitch.disabled = @YES;
        rowShareLinkPermission.disabled = @YES;
        rowPassword.disabled = @YES;
        rowHideDownload.disabled = @YES;
        rowExpirationDate.disabled = @YES;
        rowExpirationDateSwitch.disabled = @YES;
        rowSendLinkTo.disabled = @YES;
        rowFindUser.disabled = @YES;
        
        XLFormSectionDescriptor *section = [self.form formSectionAtIndex:4];
        [section.formRows removeAllObjects];
    }
    
    self.form.disabled = NO;
    
    [self.tableView reloadData];
    
    self.form.delegate = self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Change Value & Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)sendLinkTo:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    NSString *sharedLink = self.itemShareLink.token;
    NSString *url;
    
    if ([sharedLink hasPrefix:@"http://"] || [sharedLink hasPrefix:@"https://"]) {
        
        url = sharedLink;
        
    } else if (self.itemShareLink.url) {
        
        url = self.itemShareLink.url;
        
    } else {

        url = [NSString stringWithFormat:@"%@/%@%@", appDelegate.activeUrl, k_share_link_middle_part_url_after_version_8, sharedLink];

    }

    NSArray *activityItems = @[[NSString stringWithFormat:@""], [NSURL URLWithString:url]];
    NSArray *applicationActivities = nil;
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:applicationActivities];
    
    activityController.popoverPresentationController.sourceView = self.view;
    NSIndexPath *indexPath = [self.form indexPathOfFormRow:sender];
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    activityController.popoverPresentationController.sourceRect = CGRectOffset(cellRect, -self.tableView.contentOffset.x, -self.tableView.contentOffset.y);
    
    [self presentViewController:activityController animated:YES completion:nil];
}

- (void)shareUserButton:(XLFormRowDescriptor *)rowDescriptor
{
    [self deselectFormRow:rowDescriptor];
    
    self.shareUserOC = [[UIStoryboard storyboardWithName:@"CCShare" bundle:nil] instantiateViewControllerWithIdentifier:@"CCShareUserOC"];
    self.shareUserOC.metadata = self.metadata;
    self.shareUserOC.serverUrl = self.serverUrl;
    self.shareUserOC.itemsShareWith = self.itemsShareWith;
    self.shareUserOC.isDirectory = self.metadata.directory;
    
    [self.shareUserOC setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:self.shareUserOC animated:YES completion:NULL];
}

- (void)sharePermissionButton:(XLFormRowDescriptor *)rowDescriptor
{
    [self deselectFormRow:rowDescriptor];
    
    self.sharePermissionOC = [[UIStoryboard storyboardWithName:@"CCShare" bundle:nil] instantiateViewControllerWithIdentifier:@"CCSharePermissionOC"];
    self.sharePermissionOC.idRemoteShared = rowDescriptor.tag;
    self.sharePermissionOC.metadata = self.metadata;
    self.sharePermissionOC.serverUrl = self.serverUrl;
    
    [self.sharePermissionOC setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:self.sharePermissionOC animated:YES completion:NULL];
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    //OCSharedDto *shareDto = [appDelegate.sharesID objectForKey:self.shareLink];
    
    if ([rowDescriptor.tag isEqualToString:@"shareLinkSwitch"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            if (capabilities.isFilesSharingPublicPasswordEnforced == YES) {
                
                __weak __typeof(UIAlertController) *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_enforce_password_protection_",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
                [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.secureTextEntry = true;
                    [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                }];
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                    [self reloadDatasource];
                }];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    NSString *password = alertController.textFields.firstObject.text;
                    XLFormRowDescriptor *rowPassword = [self.form formRowWithTag:@"password"];
                    rowPassword.value = password;
                    [self share:self.metadata serverUrl:self.serverUrl password:password permission:1 hideDownload:false];
                    [self disableForm];
                }];
                
                okAction.enabled = NO;
                
                [alertController addAction:cancelAction];
                [alertController addAction:okAction];
                
                [self presentViewController:alertController animated:YES completion:nil];
                
            } else {
                
                [self share:self.metadata serverUrl:self.serverUrl password:@"" permission:1 hideDownload:false];
                [self disableForm];
            }
            
        } else {
            
            // unshare
            [self unShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl];
            [self disableForm];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"shareLinkPermission"]) {
        
        [self updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:nil expirationTime:nil permission:[self getShareLinkPermission:newValue] hideDownload:false];
        [self disableForm];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"hideDownload"]) {
        
        BOOL hideDownload = [newValue boolValue];
        
        [self updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:nil expirationTime:nil permission:0 hideDownload:hideDownload];
        [self disableForm];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"expirationDateSwitch"]) {
        
        // remove expiration date
        if ([[rowDescriptor.value valueData] boolValue] == NO) {
            
            [self updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:nil expirationTime:@"" permission:0 hideDownload:false];
            [self disableForm];
            
        } else {
            
            // new date
            XLFormRowDescriptor *rowExpirationDate = [self.form formRowWithTag:@"expirationDate"];
            NSString *expirationDate = [self convertDateInServerFormat:rowExpirationDate.value];
            
            [self updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:nil expirationTime:expirationDate permission:0 hideDownload:false];
            [self disableForm];
        }
    }
}

- (void)formRowHasBeenRemoved:(XLFormRowDescriptor *)formRow atIndexPath:(NSIndexPath *)indexPath
{
    long long idRemoteShared = [formRow.tag longLongValue];
    
    if ([formRow.rowType isEqualToString:@"button"] && idRemoteShared > 0) {
        
        [self unShare:formRow.tag metadata:self.metadata serverUrl:self.serverUrl];
        [self disableForm];
    }
}

- (void)beginEditing:(XLFormRowDescriptor *)rowDescriptor
{
    [super beginEditing:rowDescriptor];
    
    if ([rowDescriptor.tag isEqualToString:@"expirationDate"]) {
        
        self.endButton.enabled = NO;
    }
}

- (void)endEditing:(XLFormRowDescriptor *)rowDescriptor
{
    [super endEditing:rowDescriptor];
    
    //OCSharedDto *shareDto = [appDelegate.sharesID objectForKey:self.shareLink];
    
    if ([rowDescriptor.tag isEqualToString:@"expirationDate"]) {
        
        NSDate *old = [NSDate dateWithTimeIntervalSince1970: self.itemShareLink.expirationDate];
        NSDate *new = rowDescriptor.value;
        
        if ([old compare:new] != NSOrderedSame) {
        
            NSString *expirationDate = [self convertDateInServerFormat:rowDescriptor.value];
        
            [self updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:nil expirationTime:expirationDate permission:0 hideDownload:false];
            [self disableForm];
        }
        
        self.endButton.enabled = YES;
    }
    
    if ([rowDescriptor.tag isEqualToString:@"password"]) {
        
        NSString *password = rowDescriptor.value;
        
        // Public Password Enforced Test
        if (capabilities.isFilesSharingPublicPasswordEnforced == YES && password == nil) {
            
            [appDelegate messageNotification:@"_share_link_" description:@"_password_obligatory_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:k_CCErrorInternalError];

            [self reloadDatasource];
            
        } else {
        
            // if the password is not changed or is 0 lenght
            if ([[self.itemShareLink shareWith] isEqualToString:password]) {
                
                [self reloadDatasource];
                
            } else {
                
                if (password == nil)
                    password = @"";
                
                if (self.shareLink) {
                    
                    [self updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:password expirationTime:nil permission:0 hideDownload:false];
                    [self disableForm];
                }
            }
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Button =====
#pragma --------------------------------------------------------------------------------------------

- (IBAction)endButtonAction:(id)sender
{
    [self.tableView endEditing:YES];
    
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.metadata.serverUrl fileID:self.metadata.fileID action:k_action_MOD];
    
    [self.delegate readShareServer];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Utility =====
#pragma --------------------------------------------------------------------------------------------

- (void)minCharTextFieldDidChange:(UITextField *)sender
{
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    
    if (alertController) {
        UITextField *password = alertController.textFields.firstObject;
        UIAlertAction *okAction = alertController.actions.lastObject;
        okAction.enabled = password.text.length >= 8;
    }
}

-(void)disableForm
{
    self.form.disabled = YES;
    [self.tableView endEditing:YES];
    [self.tableView reloadData];
}

- (NSString *)convertDateInServerFormat:(NSDate *)date {
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    
    [dateFormatter setDateFormat:@"YYYY-MM-dd"];
    
    return [dateFormatter stringFromDate:date];
}

-(NSDate *)tomorrow
{
    NSDate *now = [NSDate date];
    int daysToAdd = 1;
    return [now dateByAddingTimeInterval:60*60*24*daysToAdd];
}

- (NSInteger)getShareLinkPermission:(NSString *)value
{
    if ([value isEqualToString:NSLocalizedString(@"_share_link_readonly_", nil)]) {
        return 1;
    } else if ([value isEqualToString:NSLocalizedString(@"_share_link_modify_", nil)]) {
        return 3;
    } else if ([value isEqualToString:NSLocalizedString(@"_share_link_upload_", nil)]) {
        return 4;
    } else if ([value isEqualToString:NSLocalizedString(@"_share_link_upload_modify_", nil)]) {
        return 15;
    } else {
        return 1;
    }
}

@end

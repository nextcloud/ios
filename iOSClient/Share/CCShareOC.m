//
//  CCShareOC.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 13/11/15.
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

#import "CCShareOC.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface CCShareOC ()

@end

@implementation CCShareOC

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        
        self.itemsShareWith = [[NSMutableArray alloc] init];
        
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

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"password" rowType:XLFormRowDescriptorTypePassword title:NSLocalizedString(@"_password_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"shareLinkSwitch" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_share_link_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
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
    
    self.view.backgroundColor = [NCBrandColor sharedInstance].tableBackground;
    
    [self.endButton setTitle:NSLocalizedString(@"_done_", nil) forState:UIControlStateNormal];
    self.endButton.tintColor = [NCBrandColor sharedInstance].brand;
    
    [self reloadData];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, self.metadata.fileID]]) {
        
        self.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, self.metadata.fileID]];
        
    } else {
        
        if (self.metadata.directory)
            self.fileImageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:self.metadata.iconName] color:[NCBrandColor sharedInstance].brand];
        else
            self.fileImageView.image = [UIImage imageNamed:self.metadata.iconName];

    }
    
    self.labelTitle.text = self.metadata.fileNamePrint;
    self.labelTitle.textColor = [UIColor blackColor];
    
    self.tableView.tableHeaderView = ({UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 0.1 / UIScreen.mainScreen.scale)];
        line.backgroundColor = self.tableView.separatorColor;
        line;
    });
    
    self.tableView.backgroundColor = [NCBrandColor sharedInstance].tableBackground;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Reload Data =====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadData
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    self.shareLink = [appDelegate.sharesLink objectForKey:[self.serverUrl stringByAppendingString:self.metadata.fileName]];
    self.shareUserAndGroup = [appDelegate.sharesUserAndGroup objectForKey:[self.serverUrl stringByAppendingString:self.metadata.fileName]];

    self.itemShareLink = [appDelegate.sharesID objectForKey:self.shareLink];
    if ([self.shareUserAndGroup length] > 0) self.itemsUserAndGroupLink = [self.shareUserAndGroup componentsSeparatedByString:@","];
    else self.itemsUserAndGroupLink = nil;

    self.form.delegate = nil;

    XLFormRowDescriptor *rowPassword = [self.form formRowWithTag:@"password"];
    XLFormRowDescriptor *rowShareLinkSwitch = [self.form formRowWithTag:@"shareLinkSwitch"];
    
    XLFormRowDescriptor *rowExpirationDate = [self.form formRowWithTag:@"expirationDate"];
    XLFormRowDescriptor *rowExpirationDateSwitch = [self.form formRowWithTag:@"expirationDateSwitch"];
    
    XLFormRowDescriptor *rowSendLinkTo = [self.form formRowWithTag:@"sendLinkTo"];

    // Passoword
    if ([[self.itemShareLink shareWith] length] > 0 && self.itemShareLink.shareType == shareTypeLink)
        rowPassword.value = [self.itemShareLink shareWith];
    else
        rowPassword.value = @"";

    // Share Link
    if ([self.shareLink length] > 0) {
        
        [rowShareLinkSwitch setValue:@1];
        
        rowExpirationDate.disabled = @NO;
        rowExpirationDateSwitch.disabled = @NO;

        rowSendLinkTo.disabled = @NO;
        
    } else {
        
        [rowShareLinkSwitch setValue:@0];
        
        rowExpirationDate.disabled = @YES;
        rowExpirationDateSwitch.disabled = @YES;
        
        rowSendLinkTo.disabled = @YES;
    }
    
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
            
            OCSharedDto *item = [app.sharesID objectForKey:idRemoteShared];
            
            XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:idRemoteShared rowType:XLFormRowDescriptorTypeButton];

            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
            //[row.cellConfig setObject:@(UITableViewCellAccessoryDisclosureIndicator) forKey:@"accessoryType"];
            [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"textLabel.textColor"];
            row.action.formSelector = @selector(sharePermissionButton:);
                
            if (item.shareType == shareTypeGroup) row.title = [item.shareWithDisplayName stringByAppendingString:NSLocalizedString(@"_user_is_group_", nil)];
            else row.title = item.shareWithDisplayName;
                
            [section addFormRow:row];
                
            // add users
            [self.itemsShareWith addObject:item];
        }
            
        section.footerTitle = NSLocalizedString(@"_user_sharee_footer_", nil);

    } else {
            
        section.footerTitle = @"";

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
        
    } else {

        url = [NSString stringWithFormat:@"%@/%@%@", app.activeUrl, k_share_link_middle_part_url_after_version_8, sharedLink];

    }

    NSArray *activityItems = @[[NSString stringWithFormat:@""], [NSURL URLWithString:url]];
    NSArray *applicationActivities = nil;
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:applicationActivities];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [self presentViewController:activityController animated:YES completion:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        
        UIPopoverController *popup;
        
        popup = [[UIPopoverController alloc] initWithContentViewController:activityController];
        [popup presentPopoverFromRect:CGRectMake(120, 100, 200, 400) inView:self.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
    }

}

- (void)shareUserButton:(XLFormRowDescriptor *)rowDescriptor
{
    [self deselectFormRow:rowDescriptor];
    
    self.shareUserOC = [[UIStoryboard storyboardWithName:@"CCShare" bundle:nil] instantiateViewControllerWithIdentifier:@"CCShareUserOC"];
    self.shareUserOC.delegate = self;
    self.shareUserOC.itemsShareWith = self.itemsShareWith;
    self.shareUserOC.isDirectory = self.metadata.directory;
    
    [self.shareUserOC setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:self.shareUserOC animated:YES completion:NULL];
}

- (void)sharePermissionButton:(XLFormRowDescriptor *)rowDescriptor
{
    [self deselectFormRow:rowDescriptor];
    
    self.sharePermissionOC = [[UIStoryboard storyboardWithName:@"CCShare" bundle:nil] instantiateViewControllerWithIdentifier:@"CCSharePermissionOC"];
    self.sharePermissionOC.delegate = self;
    self.sharePermissionOC.idRemoteShared = rowDescriptor.tag;
    self.sharePermissionOC.metadata = self.metadata;
    self.sharePermissionOC.serverUrl = self.serverUrl;
    
    
    [self.sharePermissionOC setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:self.sharePermissionOC animated:YES completion:NULL];
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    OCSharedDto *shareDto = [app.sharesID objectForKey:self.shareLink];
    
    if ([rowDescriptor.tag isEqualToString:@"shareLinkSwitch"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            // share
            XLFormRowDescriptor *rowPassword = [self.form formRowWithTag:@"password"];
            
            [self.delegate share:self.metadata serverUrl:self.serverUrl password:rowPassword.value];
            [self disableForm];
            
        } else {
            
            // unshare
            [self.delegate unShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl];
            [self disableForm];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"expirationDateSwitch"]) {
        
        // remove expiration date
        if ([[rowDescriptor.value valueData] boolValue] == NO) {
            
            [self.delegate updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:nil expirationTime:@"" permission:shareDto.permissions];
            [self disableForm];
            
        } else {
            
            // new date
            XLFormRowDescriptor *rowExpirationDate = [self.form formRowWithTag:@"expirationDate"];
            NSString *expirationDate = [self convertDateInServerFormat:rowExpirationDate.value];
            
            [self.delegate updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:nil expirationTime:expirationDate permission:shareDto.permissions];
            [self disableForm];
        }
    }
}

- (void)formRowHasBeenRemoved:(XLFormRowDescriptor *)formRow atIndexPath:(NSIndexPath *)indexPath
{
    long long idRemoteShared = [formRow.tag longLongValue];
    
    if ([formRow.rowType isEqualToString:@"button"] && idRemoteShared > 0) {
        
        [self.delegate unShare:formRow.tag metadata:self.metadata serverUrl:self.serverUrl];
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
    
    OCSharedDto *shareDto = [app.sharesID objectForKey:self.shareLink];
    
    if ([rowDescriptor.tag isEqualToString:@"expirationDate"]) {
        
        NSDate *old = [NSDate dateWithTimeIntervalSince1970: self.itemShareLink.expirationDate];
        NSDate *new = rowDescriptor.value;
        
        if ([old compare:new] != NSOrderedSame) {
        
            NSString *expirationDate = [self convertDateInServerFormat:rowDescriptor.value];
        
            [self.delegate updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:nil expirationTime:expirationDate permission:shareDto.permissions];
            [self disableForm];
        }
        
        self.endButton.enabled = YES;
    }
    
    if ([rowDescriptor.tag isEqualToString:@"password"]) {
        
        NSString *password = rowDescriptor.value;
        
        // if the password is not changed or is 0 lenght
        if ([[self.itemShareLink shareWith] isEqualToString:password]) {
            
            [self reloadData];
            
        } else {
            
            /*
            if (password == nil) {
                
                [self reloadData];
                return;
            }
            */
             
            if (password == nil)
                password = @"";
            
            if (self.shareLink) {
                
                [self.delegate updateShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl password:password expirationTime:nil permission:shareDto.permissions];
                [self disableForm];
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
    
    // reload delegate
    [self.delegate reloadDatasource:[[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID]];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== User & Group =====
#pragma --------------------------------------------------------------------------------------------

- (void)getUserAndGroup:(NSString *)find
{
    [self.delegate getUserAndGroup:find];
}

- (void)reloadUserAndGroup:(NSArray *)items
{
    if (self.shareUserOC)
        [self.shareUserOC reloadUserAndGroup:items];
}

- (void)shareUserAndGroup:(NSString *)user shareeType:(NSInteger)shareeType permission:(NSInteger)permission
{
    [self.delegate shareUserAndGroup:user shareeType:shareeType permission:permission metadata:self.metadata directoryID:self.metadata.directoryID serverUrl:self.serverUrl];
}

- (void)updateShare:(NSString *)share metadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password expirationTime:(NSString *)expirationTime permission:(NSInteger)permission
{
    [self.delegate updateShare:share metadata:metadata serverUrl:serverUrl password:password expirationTime:expirationTime permission:permission];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Utility =====
#pragma --------------------------------------------------------------------------------------------

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

@end

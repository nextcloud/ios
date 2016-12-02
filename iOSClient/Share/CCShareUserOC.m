//
//  CCShareUserOC.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 30/11/15.
//  Copyright (c) 2014 TWS. All rights reserved.
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

#import "CCShareUserOC.h"

#import "AppDelegate.h"

@interface CCShareUserOC ()

@end

@implementation CCShareUserOC

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        
        self.directUser = @"";
        
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
    form.assignFirstResponderOnShow = YES;
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_find_sharee_title_", nil)];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_find_sharee_footer_", nil);
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"findUser" rowType:XLFormRowDescriptorTypeName];
    [row.cellConfigAtConfigure setObject:NSLocalizedString(@"_find_sharee_", nil) forKey:@"textField.placeholder"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_direct_sharee_title_", nil)];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_direct_sharee_footer_", nil);
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"directUser" rowType:XLFormRowDescriptorTypeName];
    [row.cellConfigAtConfigure setObject:NSLocalizedString(@"_direct_sharee_", nil) forKey:@"textField.placeholder"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.selectedItems = [[NSMutableArray alloc] init];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Done
    [self.endButton setTitle:NSLocalizedString(@"_done_", nil) forState:UIControlStateNormal];
    self.endButton.tintColor = [COLOR_BRAND colorWithAlphaComponent:0.8];
    
    [self.view setTintColor:COLOR_BRAND];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Button =====
#pragma --------------------------------------------------------------------------------------------

- (IBAction)endButtonAction:(id)sender
{
    NSInteger permission;
        
    if (self.isDirectory) permission = k_max_folder_share_permission;
    else permission = k_max_file_share_permission;
    
    // start share of select users
    for (NSString *num in self.selectedItems) {
        
        OCShareUser *item = [self.users objectAtIndex:[num integerValue]];
        
        [self.delegate shareUserAndGroup:item.name shareeType:item.shareeType permission:permission];
    }
    
    // start share with a user if not be i 
    if ([self.directUser isEqual:[NSNull null]] == NO) {
    
        if ([self.directUser length] > 0 && [self.directUser isEqualToString:app.activeUser] == NO) {
        
            [self.delegate shareUserAndGroup:self.directUser shareeType:0 permission:permission];
        }
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Change Value =====
#pragma --------------------------------------------------------------------------------------------

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeBooleanCheck]) {
            
        if ([newValue boolValue] == YES)
            [self.selectedItems addObject:rowDescriptor.tag];
        if ([newValue boolValue] == NO)
            [self.selectedItems removeObject:rowDescriptor.tag];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"directUser"]) {
        
        self.directUser = newValue;
    }
}

- (void)endEditing:(XLFormRowDescriptor *)rowDescriptor
{
    [super endEditing:rowDescriptor];
    
    if ([rowDescriptor.tag isEqualToString:@"findUser"]) {
        
        rowDescriptor.value = [rowDescriptor.value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if ([rowDescriptor.value length] > 1)
            [self.delegate getUserAndGroup:rowDescriptor.value];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delegate =====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadUserAndGroup:(NSArray *)items
{
    self.users = [[NSMutableArray alloc] initWithArray:items];
    
    self.form.delegate = nil;
    
    // remove the select users and i
    for (OCShareUser *user in items) {
        
        for (OCSharedDto *item in self.itemsShareWith)
            if ([item.shareWith isEqualToString:user.name] && ((item.shareType == shareTypeGroup && user.shareeType == 1) || (item.shareType != shareTypeGroup && user.shareeType == 0)))
                [self.users removeObject:user];
        
        if ([self.itemsShareWith containsObject:user.name] || [user.name isEqualToString:app.activeUser])
            [self.users removeObject:user];
    }
    
    XLFormSectionDescriptor *section = [self.form formSectionAtIndex:1];
    [section.formRows removeAllObjects];
    
    for (OCShareUser *item in self.users) {
        
        NSInteger num = [self.users indexOfObject:item];
        
        NSString *title;
        
        if (item.shareeType == 1) title = [item.name stringByAppendingString:NSLocalizedString(@"_user_is_group_", nil)];
        else title = item.name;
        
        XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:[@(num) stringValue] rowType:XLFormRowDescriptorTypeBooleanCheck title:title];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:COLOR_BRAND forKey:@"self.tintColor"];
        
        [section addFormRow:row];
    }
    
    [self.tableView reloadData];
    
    self.form.delegate = self;
}

@end

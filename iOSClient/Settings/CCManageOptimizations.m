//
//  CCManageOptimizations.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 22/09/15.
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

#import "CCManageOptimizations.h"
#import "CCUtility.h"

@implementation CCManageOptimizations

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
        [self initializeForm];        
    }
    
    return self;
}

- (void)initializeForm
{
    XLFormDescriptor *form ;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;

    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_optimizations_", nil)];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_optimized_photos_", nil)];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_optimized_photos_how_", nil);
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"optimizedphoto" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_optimized_photos_", nil)];
    if ([CCUtility getOptimizedPhoto]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_upload_del_photos_", nil)];
    [form addFormSection:section];
    section.footerTitle = [CCUtility localizableBrand:@"_upload_del_photos_how_" table:nil];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"uploadremovephoto" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_upload_del_photos_", nil)];
    if ([CCUtility getUploadAndRemovePhoto]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];

    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    self.form = form;
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
}

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"optimizedphoto"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            [CCUtility setOptimizedPhoto:YES];
            
        } else {
            
            [CCUtility setOptimizedPhoto:NO];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"uploadremovephoto"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            [CCUtility setUploadAndRemovePhoto:YES];
            
        } else {
            
            [CCUtility setUploadAndRemovePhoto:NO];
        }
    }
}

@end

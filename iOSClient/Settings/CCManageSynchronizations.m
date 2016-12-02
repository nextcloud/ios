//
//  CCManageSynchronizations.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/11/15.
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

#import "CCManageSynchronizations.h"

#import "AppDelegate.h"

@implementation CCManageSynchronizations

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

    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_synchronizations_", nil)];
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_sync_wifi_how_", nil);
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"synchronizationswifi" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_wifi_only_", nil)];
    if ([CCUtility getSynchronizationsOnlyWiFi]) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_sync_active_", nil) sectionOptions:XLFormSectionOptionCanDelete];
    [form addFormSection:section];
    
    [self synchronizationsActive:section];
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    [self.tableView setEditing:!self.tableView.editing animated:YES];
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
    
    if ([rowDescriptor.tag isEqualToString:@"synchronizationswifi"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            [CCUtility setSynchronizationsOnlyWiFi:YES];
            
        } else {
            
            [CCUtility setSynchronizationsOnlyWiFi:NO];
        }
    }
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"[LOG] Should delete %i",(int)indexPath.row);
    
    XLFormRowDescriptor *rowDescriptor = [self.form formRowAtIndex:indexPath];
    
    [CCCoreData removeSynchronizedDirectoryID:rowDescriptor.tag activeAccount:app.activeAccount];
    
    [super tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
        
    XLFormSectionDescriptor *section = [self.form formSectionAtIndex:indexPath.section];

    [self synchronizationsActive:section];
}

- (void)synchronizationsActive:(XLFormSectionDescriptor *)section
{
    XLFormRowDescriptor *row;

    NSArray *tableSynchronized = [CCCoreData getSynchronizedDirectoryActiveAccount:app.activeAccount];
    NSString *home = [CCUtility getHomeServerUrlActiveUrl:app.activeUrl typeCloud:app.typeCloud];
    NSString *title;
    
    [section.formRows removeAllObjects];
    [self.tableView reloadData];
    
    if ([tableSynchronized count] > 0) {
        
        for (TableDirectory *directory in tableSynchronized) {
            
            /*** NEXTCLOUD OWNCLOUD ***/
            
            if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud])
                title = [directory.serverUrl stringByReplacingOccurrencesOfString:home withString:@""];
            
            /*** DROPBOX ***/

            if ([app.typeCloud isEqualToString:typeCloudDropbox])
                title = directory.serverUrl;
            
            title = [title lastPathComponent];
            if ([CCUtility isCryptoString:title]) {
                
                CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileNameData == %@) AND (directory == 1) AND (account == %@)", title, app.activeAccount] context:nil];
                title = metadata.fileNamePrint;
                row = [XLFormRowDescriptor formRowDescriptorWithTag:directory.directoryID rowType:XLFormRowDescriptorTypeInfo title:title];
                [row.cellConfig setObject:COLOR_BRAND forKey:@"textLabel.textColor"];
                
            } else {
             
                row = [XLFormRowDescriptor formRowDescriptorWithTag:directory.directoryID rowType:XLFormRowDescriptorTypeInfo title:title];
            }
            
            [section addFormRow:row];
        }
        
        section.title = NSLocalizedString(@"_sync_active_", nil);
        section.footerTitle = NSLocalizedString(@"_sync_active_footer_", nil);
        
    } else {
        
        section.title = @"";
        section.footerTitle = @"";
    }
}

@end

//
//  CCManagePhotos.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 22/05/16.
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

#import "CCManagePhotos.h"

#import "AppDelegate.h"

@implementation CCManagePhotos

//  From Settings
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {

        [self initializeForm];
    }
    
    return self;
}

- (void)initializeForm
{
    XLFormDescriptor *form ;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_photo_camera_", nil)];

    // Camera Upload change location

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_change_folder_photos_", nil)];
    section.footerTitle = NSLocalizedString(@"_upload_camera_change_location_footer_", nil);
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"camerauploadlocationnow" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_upload_camera_location_now_", nil)];
    row.value = [CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    NSString *title = [NSString stringWithFormat:@"%@ : %@", NSLocalizedString(@"_upload_camera_location_default_", nil), folderDefaultCameraUpload];
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"camerauploadlocationdefault" rowType:XLFormRowDescriptorTypeButton title:title];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsManagePhotos] forKey:@"imageView.image"];
    row.action.formSelector = @selector(locationDefault:);
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"camerauploadchangelocation" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_upload_camera_change_location_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsManagePhotosChange] forKey:@"imageView.image"];
    row.action.formSelector = @selector(changeLocation:);
    [section addFormRow:row];
    
    // end
    
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
    
    //
    [self reloadForm];
}

- (void)move:(NSString *)serverUrlTo title:(NSString *)title selectedMetadatas:(NSArray *)selectedMetadatas
{
    NSString *fileName, *newPath;
    
    if (serverUrlTo) {
        
        /*** NEXTCLOUD OWNCLOUD ***/
        
        if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) {
            
            NSURL *url = [NSURL URLWithString:[serverUrlTo stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            fileName = [serverUrlTo lastPathComponent];
            
            newPath = [[url URLByDeletingLastPathComponent] absoluteString];
            newPath = [newPath substringToIndex:[newPath length] -1];
            
        }
        
        /*** DROPBOX ***/

        if ([app.typeCloud isEqualToString:typeCloudDropbox]) {
            
            fileName = [serverUrlTo lastPathComponent];
            newPath = [serverUrlTo stringByDeletingLastPathComponent];

        }
        
        if ([serverUrlTo isEqualToString:[CCUtility getHomeServerUrlActiveUrl:app.activeUrl typeCloud:app.typeCloud]]) {
            
            UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_camera_upload_not_select_home_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
            [alertView show];
            
        } else {
            
            NSString *oldPath = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
            
            [CCCoreData setCameraUploadFolderName:fileName activeAccount:app.activeAccount];
            [CCCoreData setCameraUploadFolderPath:newPath activeUrl:app.activeUrl typeCloud:app.typeCloud activeAccount:app.activeAccount];
            
            [CCCoreData clearDateReadDirectory:oldPath activeAccount:app.activeAccount];
            [CCCoreData clearDateReadDirectory:newPath activeAccount:app.activeAccount];
            
            if (app.activeAccount && app.activeUrl && app.activePhotosCameraUpload)
                [app.activePhotosCameraUpload reloadDatasourceForced];
            
            [self reloadForm];
        }
    }
}

- (void)done:(XLFormRowDescriptor *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)changeLocation:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMove"];
    
    CCMove *viewController = (CCMove *)navigationController.topViewController;

    viewController.delegate = self;
    viewController.move.title = NSLocalizedString(@"_select_", nil);
    viewController.onlyClearDirectory = YES;
    viewController.tintColor = COLOR_BRAND;
    viewController.barTintColor = COLOR_BAR;
    viewController.tintColorTitle = COLOR_GRAY;
    viewController.networkingOperationQueue = app.netQueue;
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)locationDefault:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
  
    NSString *oldPath = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
    NSString *newPath = [CCUtility getHomeServerUrlActiveUrl:app.activeUrl typeCloud:app.typeCloud];

    [CCCoreData setCameraUploadFolderName:folderDefaultCameraUpload activeAccount:app.activeAccount];
    [CCCoreData setCameraUploadFolderPath:newPath activeUrl:app.activeUrl typeCloud:app.typeCloud activeAccount:app.activeAccount];
    
    [CCCoreData clearDateReadDirectory:oldPath activeAccount:app.activeAccount];
    [CCCoreData clearDateReadDirectory:newPath activeAccount:app.activeAccount];

    // rebuild
    if (app.activeAccount && app.activeUrl && app.activePhotosCameraUpload)
        [app.activePhotosCameraUpload reloadDatasourceForced];

    /*** NEXTCLOUD OWNCLOUD ***/
    
    // Create Folder cameraUpload
    if (([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) && app.activeMain)
        [app.activeMain createFolderCameraUpload];

    [self reloadForm];
}

- (void)reloadForm
{
    self.form.delegate = nil;
    
    XLFormRowDescriptor *rowCameraUploadLocationNow = [self.form formRowWithTag:@"camerauploadlocationnow"];
    [rowCameraUploadLocationNow setValue:[CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount]];
    
    [self.tableView reloadData];
    
    self.form.delegate = self;
}

@end

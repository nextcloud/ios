//
//  CCManageAutoUpload.m
//  Nextcloud
//
//  Created by Marino Faggiana on 01/09/15.
//  Copyright (c) 2015 Marino Faggiana. All rights reserved.
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

#import <Photos/Photos.h>
#import "CCManageAutoUpload.h"
#import "CCUtility.h"
#import "NCBridgeSwift.h"

@interface CCManageAutoUpload () <NCSelectDelegate>
{
    AppDelegate *appDelegate;
}
@end

@implementation CCManageAutoUpload

- (void)initializeForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
 
    tableAccount *activeAccount = [[NCManageDatabase shared] getActiveAccount];
    
    // Auto Upload
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_autoupload_description_", nil);

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUpload" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    if (activeAccount.autoUpload) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [section addFormRow:row];

    // Auto Upload Directory
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadDirectory" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_autoupload_select_folder_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"foldersOnTop"] imageWithColor:NCBrandColor.shared.gray size:25] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    //[row.cellConfig setObject:@(UITableViewCellAccessoryDisclosureIndicator) forKey:@"accessoryType"];
    row.action.formSelector = @selector(selectAutomaticUploadFolder);
    [section addFormRow:row];
    
    // Auto Upload Photo
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadImage" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_photos_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (activeAccount.autoUploadImage) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadWWAnPhoto" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_wifi_only_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (activeAccount.autoUploadWWAnPhoto) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload Video
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadVideo" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_videos_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (activeAccount.autoUploadVideo) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadWWAnVideo" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_wifi_only_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (activeAccount.autoUploadWWAnVideo) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Delete asset
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"removePhotoCameraRoll" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_remove_photo_CameraRoll_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (activeAccount.autoUploadDeleteAssetLocalIdentifier) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload Background
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadBackground" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_background_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (activeAccount.autoUploadBackground) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload Full
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    NSString *title = NSLocalizedString(@"_autoupload_fullphotos_", nil);
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadFull" rowType:XLFormRowDescriptorTypeBooleanSwitch title:title];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    row.value = 0;
    if (activeAccount.autoUploadFull) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload create subfolder

    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadCreateSubfolder" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_create_subfolder_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (activeAccount.autoUploadCreateSubfolder) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload file name
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadFileName" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_autoupload_filenamemask_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.secondarySystemGroupedBackground;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.shared.label forKey:@"textLabel.textColor"];
    row.action.viewControllerClass = [NCManageAutoUploadFileName class];
    [section addFormRow:row];
    
    // end
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    self.tableView.showsVerticalScrollIndicator = NO;
    self.form = form;
}

// MARK: - View Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_settings_autoupload_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.view.backgroundColor = NCBrandColor.shared.systemGroupedBackground;
    
    self.tableView.backgroundColor = NCBrandColor.shared.systemGroupedBackground;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initialize) name:NCGlobal.shared.notificationCenterInitialize object:nil];
    
    [self initializeForm];
    [self reloadForm];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    appDelegate.activeViewController = self;
    
    // Request permission for camera roll access
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        switch (status) {
            case PHAuthorizationStatusRestricted:
                NSLog(@"[LOG] user can't grant access to camera roll");
                break;
            case PHAuthorizationStatusDenied:
                NSLog(@"[LOG] user denied access to camera roll");
                break;
            default:
                break;
        }
    }];
}

- (void)initialize
{
    [[self navigationController] popViewControllerAnimated:YES];
}

#pragma mark - NotificationCenter


#pragma mark -

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    tableAccount *activeAccount = [[NCManageDatabase shared] getActiveAccount];
    
    if ([rowDescriptor.tag isEqualToString:@"autoUpload"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
                        
            [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUpload" state:YES];
            
            // Default
            [[NCManageDatabase shared] setAccountAutoUploadFileName:nil];
            [[NCManageDatabase shared] setAccountAutoUploadDirectory:nil urlBase:appDelegate.urlBase account:appDelegate.account];
            
            // verifichiamo che almeno uno dei servizi (foto video) siano attivi, in caso contrario attiviamo le foto
            if (activeAccount.autoUploadImage == NO && activeAccount.autoUploadVideo == NO) {
                [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadImage" state:YES];
                [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadVideo" state:YES];
            }
            
            [[NCAutoUpload shared] alignPhotoLibraryWithViewController:self];
            
        } else {
            
            [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUpload" state:NO];
            [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadFull" state:NO];

            // remove
            [[NCManageDatabase shared] clearMetadatasUploadWithAccount:appDelegate.account];
        }
        
        [self reloadForm];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"removePhotoCameraRoll"]) {
        
        [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadDeleteAssetLocalIdentifier" state:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadBackground"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
                        
            [[NCAskAuthorization shared]  askAuthorizationLocationManagerWithCompletion: ^(BOOL hasFullPermissions) {
                
                if (hasFullPermissions == YES) {
                    
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_autoupload_background_title_", nil) message:NSLocalizedString(@"_autoupload_background_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                    
                    [alertController addAction:okAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                    
                    [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadBackground" state:YES];
                    [[NCAutoUpload shared] startSignificantChangeUpdates];
                        
                } else {
                     
                    [self reloadForm];
                }
            }];
            
        } else {
            
            [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
            [[NCAutoUpload shared] stopSignificantChangeUpdates];
        }
    }

    if ([rowDescriptor.tag isEqualToString:@"autoUploadFull"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            [[NCAutoUpload shared] autoUploadFullPhotosWithViewController:self log:@"Auto upload full"];
            [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadFull" state:YES];
            
        } else {
            
            [[NCManageDatabase shared] clearMetadatasUploadWithAccount:appDelegate.account];
            [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadFull" state:NO];
        }
    }

    if ([rowDescriptor.tag isEqualToString:@"autoUploadImage"]) {
        
        [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadImage" state:[[rowDescriptor.value valueData] boolValue]];

        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [[NCAutoUpload shared] alignPhotoLibraryWithViewController:self];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadWWAnPhoto"]) {
        
        [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadWWAnPhoto" state:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadVideo"]) {
    
        [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadVideo" state:[[rowDescriptor.value valueData] boolValue]];

        if ([[rowDescriptor.value valueData] boolValue] == YES){
            [[NCAutoUpload shared] alignPhotoLibraryWithViewController:self];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadWWAnVideo"]) {
        
        [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadWWAnVideo" state:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadCreateSubfolder"]) {
        
        [[NCManageDatabase shared] setAccountAutoUploadProperty:@"autoUploadCreateSubfolder" state:[[rowDescriptor.value valueData] boolValue]];
    }
}

- (void)done:(XLFormRowDescriptor *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reloadForm
{
    self.form.delegate = nil;
    
    XLFormRowDescriptor *rowAutoUpload = [self.form formRowWithTag:@"autoUpload"];
    
    XLFormRowDescriptor *rowAutoUploadImage = [self.form formRowWithTag:@"autoUploadImage"];
    XLFormRowDescriptor *rowAutoUploadWWAnPhoto = [self.form formRowWithTag:@"autoUploadWWAnPhoto"];
    
    XLFormRowDescriptor *rowAutoUploadVideo = [self.form formRowWithTag:@"autoUploadVideo"];
    XLFormRowDescriptor *rowAutoUploadWWAnVideo = [self.form formRowWithTag:@"autoUploadWWAnVideo"];
    
    XLFormRowDescriptor *rowRemovePhotoCameraRoll = [self.form formRowWithTag:@"removePhotoCameraRoll"];

    XLFormRowDescriptor *rowAutoUploadBackground = [self.form formRowWithTag:@"autoUploadBackground"];
    
    XLFormRowDescriptor *rowAutoUploadFull = [self.form formRowWithTag:@"autoUploadFull"];
    
    XLFormRowDescriptor *rowAutoUploadCreateSubfolder = [self.form formRowWithTag:@"autoUploadCreateSubfolder"];
    
    XLFormRowDescriptor *rowAutoUploadFileName = [self.form formRowWithTag:@"autoUploadFileName"];
        
    // - STATUS ---------------------
    tableAccount *activeAccount = [[NCManageDatabase shared] getActiveAccount];
    
    if (activeAccount.autoUpload)
        [rowAutoUpload setValue:@1]; else [rowAutoUpload setValue:@0];
    
    if (activeAccount.autoUploadImage)
        [rowAutoUploadImage setValue:@1]; else [rowAutoUploadImage setValue:@0];
    
    if (activeAccount.autoUploadWWAnPhoto)
        [rowAutoUploadWWAnPhoto setValue:@1]; else [rowAutoUploadWWAnPhoto setValue:@0];
    
    if (activeAccount.autoUploadVideo)
        [rowAutoUploadVideo setValue:@1]; else [rowAutoUploadVideo setValue:@0];
    
    if (activeAccount.autoUploadWWAnVideo)
        [rowAutoUploadWWAnVideo setValue:@1]; else [rowAutoUploadWWAnVideo setValue:@0];
    
    if (activeAccount.autoUploadDeleteAssetLocalIdentifier)
           [rowRemovePhotoCameraRoll setValue:@1]; else [rowRemovePhotoCameraRoll setValue:@0];
    
    if (activeAccount.autoUploadBackground)
        [rowAutoUploadBackground setValue:@1]; else [rowAutoUploadBackground setValue:@0];
    
    if (activeAccount.autoUploadFull)
        [rowAutoUploadFull setValue:@1]; else [rowAutoUploadFull setValue:@0];
    
    if (activeAccount.autoUploadCreateSubfolder)
        [rowAutoUploadCreateSubfolder setValue:@1]; else [rowAutoUploadCreateSubfolder setValue:@0];

    // - HIDDEN --------------------------------------------------------------------------
    
    rowAutoUploadImage.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    rowAutoUploadWWAnPhoto.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowAutoUploadVideo.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    rowAutoUploadWWAnVideo.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowRemovePhotoCameraRoll.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];

    rowAutoUploadBackground.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowAutoUploadFull.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowAutoUploadCreateSubfolder.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowAutoUploadFileName.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
        
    // -----------------------------------------------------------------------------------
    
    [self.tableView reloadData];
    
    self.form.delegate = self;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NCGlobal.shared.heightCellSettings;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    tableAccount *activeAccount = [[NCManageDatabase shared] getActiveAccount];
    NSString *sectionName;
    NSString *autoUploadPath = [NSString stringWithFormat:@"%@/%@", [[NCManageDatabase shared] getAccountAutoUploadDirectoryWithUrlBase:appDelegate.urlBase account:appDelegate.account], [[NCManageDatabase shared] getAccountAutoUploadFileName]];

    switch (section)
    {
        case 0:
            sectionName = NSLocalizedString(@"_autoupload_description_", nil);
            break;
        case 1:
            if (activeAccount.autoUpload) sectionName = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"_autoupload_current_folder_", nil), [CCUtility returnPathfromServerUrl:autoUploadPath urlBase:appDelegate.urlBase account:appDelegate.account]];
            else sectionName = @"";
            break;
        case 4:
            if (activeAccount.autoUpload) sectionName = NSLocalizedString(@"_remove_photo_CameraRoll_desc_", nil);
            else sectionName = @"";
            break;
        case 5:
            if (activeAccount.autoUpload) sectionName = NSLocalizedString(@"_autoupload_description_background_", nil);
            else sectionName = @"";
            break;
        case 6:
            if (activeAccount.autoUpload) sectionName =  NSLocalizedString(@"_autoupload_fullphotos_footer_", nil);
            else sectionName = @"";
            break;
        case 7:
            if (activeAccount.autoUpload) sectionName =  NSLocalizedString(@"_autoupload_create_subfolder_footer_", nil);
            else sectionName = @"";
            break;
        case 8:
            if (activeAccount.autoUpload) sectionName =  NSLocalizedString(@"_autoupload_filenamemask_footer_", nil);
            else sectionName = @"";
            break;
    }
    return sectionName;
}

- (void)dismissSelectWithServerUrl:(NSString *)serverUrl metadata:(tableMetadata *)metadata type:(NSString *)type items:(NSArray *)items overwrite:(BOOL)overwrite copy:(BOOL)copy move:(BOOL)move
{
    if (serverUrl != nil) {
        
        if ([serverUrl isEqualToString:[[NCUtilityFileSystem shared] getHomeServerWithAccount:appDelegate.account]]) {
            [[NCContentPresenter shared] messageNotification:@"_error_" description:@"_autoupload_error_select_folder_" delay:[[NCGlobal shared] dismissAfterSecond] type:messageTypeError errorCode:NCGlobal.shared.errorInternalError];
            return;
        }
        
        // Settings new folder Automatatic upload
        [[NCManageDatabase shared] setAccountAutoUploadFileName:serverUrl.lastPathComponent];
        [[NCManageDatabase shared] setAccountAutoUploadDirectory:[[NCUtilityFileSystem shared] deletingLastPathComponentWithAccount:appDelegate.account serverUrl:serverUrl] urlBase:appDelegate.urlBase account:appDelegate.account];
        // Reload
        [self.tableView reloadData];
    }
}

- (void)selectAutomaticUploadFolder
 {
     UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"NCSelect" bundle:nil] instantiateInitialViewController];
     NCSelect *viewController = (NCSelect *)navigationController.topViewController;
     
     viewController.delegate = self;
     viewController.typeOfCommandView = 1;
     
     [self presentViewController:navigationController animated:YES completion:^{
         [self.tableView reloadData];
     }];
 }

@end

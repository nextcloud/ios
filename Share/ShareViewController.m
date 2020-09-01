//
//  ShareViewController.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 26/01/16.
//  Copyright (c) 2016 Marino Faggiana. All rights reserved.
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

#import "ShareViewController.h"
#import "NCBridgeSwift.h"

@import MobileCoreServices;

@interface ShareViewController () <NCSelectDestinationDelegate>
{
    NSURL *dirGroup;
    NSUInteger totalSize;
    
    NSExtensionItem *inputItem;
    
    UIColor *barTintColor;
    UIColor *tintColor;
    
    NSString *fileNameOriginal;
    
    UIBarButtonItem *rightButtonUpload, *leftButtonCancel;
}
@end

@implementation ShareViewController

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

-(void)viewDidLoad
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (tableAccount == nil) {
        
        // close now
        [self performSelector:@selector(closeShareViewController) withObject:nil afterDelay:0.1];
        
        return;
        
    } else {
        
        NSInteger serverVersionMajor = [[NCManageDatabase sharedInstance] getCapabilitiesServerIntWithAccount:tableAccount.account elements:NCElementsJSON.shared.capabilitiesVersionMajor];
        NSString *webDav = [[NCUtility shared] getWebDAVWithAccount:tableAccount.account];
        
        // Networking
        [[NCCommunicationCommon shared] setupWithAccount:tableAccount.account user:tableAccount.user userId:tableAccount.userID password:[CCUtility getPassword:tableAccount.account] urlBase:tableAccount.urlBase userAgent:[CCUtility getUserAgent] webDav:webDav dav:nil nextcloudVersion:serverVersionMajor delegate:[NCNetworking shared]];
       
        _account = tableAccount.account;
        _urlBase = tableAccount.urlBase;
        
        if ([_account isEqualToString:[CCUtility getAccountExt]]) {
            
            // load
            
            _serverUrl = [CCUtility getServerUrlExt];
            
            _destinyFolderButton.title = [NSString stringWithFormat:NSLocalizedString(@"_destiny_folder_", nil), [CCUtility getTitleServerUrlExt]];
            
        } else {
            
            // Default settings
            
            [CCUtility setAccountExt:self.account];

            _serverUrl  = [[NCUtility shared] getHomeServerWithUrlBase:tableAccount.urlBase account:tableAccount.account];
            [CCUtility setServerUrlExt:_serverUrl];

            _destinyFolderButton.title = [NSString stringWithFormat:NSLocalizedString(@"_destiny_folder_", nil), NSLocalizedString(@"_home_", nil)];
            [CCUtility setTitleServerUrlExt:NSLocalizedString(@"_home_", nil)];
        }
    }
    
    self.filesName = [[NSMutableArray alloc] init];
    
    self.hud = [[CCHud alloc] initWithView:self.navigationController.view];
    
    [self.shareTable registerNib:[UINib nibWithNibName:@"CCCellShareExt" bundle:nil] forCellReuseIdentifier:@"ShareExtCell"];
    
    [self navigationBarToolBar];
    
    [self loadDataSwift];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
        
    self.view.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
    self.shareTable.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
}

- (void)closeShareViewController
{
    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems completionHandler:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"[LOG] bye bye, Nextcloud Share Extension!");
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == TextField Delegate ==
#pragma --------------------------------------------------------------------------------------------

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    rightButtonUpload.enabled = false;
    fileNameOriginal = textField.text;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    rightButtonUpload.enabled = true;
    NSInteger index = [self.filesName indexOfObject:fileNameOriginal];
    if (index != NSNotFound) {
        self.filesName[index] = textField.text;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSError *error;
    
    if ([string isEqualToString:@"\n"]) {
        
        //NSString *fileName = [textField.text stringByDeletingPathExtension];
        NSString *ext = [textField.text pathExtension];

        if (![ext isEqualToString:@""]) {
            NSString *fileNameAtPath = [NSTemporaryDirectory() stringByAppendingString:fileNameOriginal];
            NSString *fileNameToPath = [NSTemporaryDirectory() stringByAppendingString:textField.text];
            
            [[NSFileManager defaultManager] moveItemAtPath:fileNameAtPath toPath:fileNameToPath error:&error];
            
            if (error != nil) {
                textField.text = fileNameOriginal;
            }
        } else {
            textField.text = fileNameOriginal;
        }
        
        [textField endEditing:true];
        return false;
    }
    
    return true;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Action ==
#pragma --------------------------------------------------------------------------------------------

- (void)navigationBarToolBar
{
    // Theming
    if ([NCBrandOptions sharedInstance].use_themingColor) {
        NSString *themingColor = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:self.account elements:NCElementsJSON.shared.capabilitiesThemingColor];
        NSString *themingColorElement = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:self.account elements:NCElementsJSON.shared.capabilitiesThemingColorElement];
        NSString *themingColorText = [[NCManageDatabase sharedInstance] getCapabilitiesServerStringWithAccount:self.account elements:NCElementsJSON.shared.capabilitiesThemingColorText];
        [CCGraphics settingThemingColor:themingColor themingColorElement:themingColorElement themingColorText:themingColorText];
    }
    self.navigationController.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand;
    self.navigationController.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText;
    
    self.toolBar.barTintColor = NCBrandColor.sharedInstance.tabBar;
    self.toolBar.tintColor = [UIColor grayColor];
    
    // Upload
    rightButtonUpload = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_save_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(selectPost)];
    
    // Cancel
    leftButtonCancel = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancelPost)];
    
    // Title
    [self.navigationController.navigationBar setTitleTextAttributes: @{NSForegroundColorAttributeName:self.navigationController.navigationBar.tintColor}];
    
    self.navigationItem.title = [NCBrandOptions sharedInstance].brand;
    self.navigationItem.leftBarButtonItem = leftButtonCancel;
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:rightButtonUpload, nil];
    self.navigationItem.hidesBackButton = YES;
}

- (void)moveServerUrlTo:(NSString *)serverUrlTo title:(NSString *)title type:(NSString *)type
{
    // DENIED e2e
    if ([CCUtility isFolderEncrypted:serverUrlTo e2eEncrypted:false account:self.account urlBase:self.urlBase]) {
        return;
    }
    
    if (serverUrlTo)
        _serverUrl = serverUrlTo;
    
    if (title) {
        self.destinyFolderButton.title = [NSString stringWithFormat:NSLocalizedString(@"_destiny_folder_", nil), title];
        [CCUtility setTitleServerUrlExt:title];
    } else {
        self.destinyFolderButton.title = [NSString stringWithFormat:NSLocalizedString(@"_destiny_folder_", nil), NSLocalizedString(@"_home_", nil)];
        [CCUtility setTitleServerUrlExt:NSLocalizedString(@"_home_", nil)];
    }
    
    [CCUtility setAccountExt:self.account];
    [CCUtility setServerUrlExt:_serverUrl];
}

- (IBAction)destinyFolderButtonTapped:(UIBarButtonItem *)sender
{
    UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"NCSelectDestination" bundle:nil] instantiateInitialViewController];
    
    NCSelectDestination *viewController = (NCSelectDestination *)navigationController.topViewController;
    
    viewController.delegate = self;
    viewController.move.title = NSLocalizedString(@"_select_", nil);
    viewController.tintColor = tintColor;
    viewController.barTintColor = barTintColor;
    viewController.tintColorTitle = tintColor;
    // E2EE
    viewController.includeDirectoryE2EEncryption = NO;

    [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)selectPost
{
    if ([self.filesName count] > 0) {
    
        [self.hud visibleHudTitle:NSLocalizedString(@"_uploading_", nil) mode:MBProgressHUDModeDeterminate color:NCBrandColor.sharedInstance.brandElement];
        
        NSString *fileName = [self.filesName objectAtIndex:0];
        NSString *fileNameLocal = [NSTemporaryDirectory() stringByAppendingString:fileName];

        // CONVERSION -->
        
        if ([fileName.pathExtension.uppercaseString isEqualToString:@"HEIC"] && [CCUtility getFormatCompatibility]) {
            UIImage *image = [UIImage imageWithContentsOfFile:fileNameLocal];
            if (image != nil) {
                fileName = fileName.stringByDeletingPathExtension;
                fileName = [NSString stringWithFormat:@"%@.jpg", fileName];
                [self.filesName replaceObjectAtIndex:0 withObject:fileName];
                fileNameLocal = [NSTemporaryDirectory() stringByAppendingString:fileName];
                [UIImageJPEGRepresentation(image, 1.0) writeToFile:fileNameLocal atomically:YES];
                
                [self.shareTable reloadData];
            }
        }
        
        // <--
        
        NSString *fileNameForUpload = [[NCUtility shared] createFileName:fileName serverUrl:self.serverUrl account:self.account];
        NSString *fileNameServer = [NSString stringWithFormat:@"%@/%@", self.serverUrl, fileNameForUpload];
        
        [[NCCommunication shared] uploadWithServerUrlFileName:fileNameServer fileNameLocalPath:fileNameLocal dateCreationFile:nil dateModificationFile:nil customUserAgent:nil addCustomHeaders:nil progressHandler:^(NSProgress * progress) {
            [self.hud progress:progress.fractionCompleted];
        } completionHandler:^(NSString *account, NSString *ocId, NSString *etag, NSDate *date, int64_t size, NSInteger errorCode, NSString *errorDescription) {
            [self.hud hideHud];
            [self.filesName removeObject:fileName];
           
            if (errorCode == 0) {
               
                [CCUtility copyFileAtPath:fileNameLocal toPath:[CCUtility getDirectoryProviderStorageOcId:ocId fileNameView:fileNameForUpload]];
               
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] createMetadataWithAccount:self.account fileName:fileNameForUpload ocId:ocId serverUrl:self.serverUrl urlBase:self.urlBase url:@"" contentType:@"" livePhoto:false];
                               
                metadata.date = date;
                metadata.etag = etag;
                metadata.serverUrl = self.serverUrl;
                metadata.size = size;
                
                [[NCManageDatabase sharedInstance] addMetadata:metadata];
                [[NCManageDatabase sharedInstance] addLocalFileWithMetadata:metadata];
               
                [self.shareTable performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
                [self performSelector:@selector(selectPost) withObject:nil];
               
            } else {
               
                UIAlertController * alert= [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message: errorDescription preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                   [alert dismissViewControllerAnimated:YES completion:nil];
                   [self closeShareViewController];
                }];
                [alert addAction:ok];
                [self presentViewController:alert animated:YES completion:nil];
            }
        }];
        
    } else {
        
        [self closeShareViewController];
    }
}

- (void)cancelPost
{
    // rimuoviamo i file+ico
    for (NSString *fileName in self.filesName) {
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:fileName] error:nil];
    }
    
    [self closeShareViewController];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Swipe Table DELETE -> menu =====
#pragma--------------------------------------------------------------------------------------------

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self setEditing:NO animated:YES];
    
    NSString *fileName = [self.filesName objectAtIndex:indexPath.row];
    
    [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:fileName] error:nil];

    [self.filesName removeObjectAtIndex:indexPath.row];
    
    if ([self.filesName count] == 0) [self closeShareViewController];
    else [self.shareTable performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Table ==
#pragma --------------------------------------------------------------------------------------------

- (void)loadDataSwift
{
    CCloadItemData *loadItem = [[CCloadItemData alloc] init];
    
    [loadItem loadFiles:NSTemporaryDirectory() extensionContext:self.extensionContext vc:self];
}

- (void)reloadData:(NSArray *)files
{
    totalSize = 0;

    for (NSString *file in files) {
        
        NSUInteger fileSize = (NSInteger)[[[NSFileManager defaultManager] attributesOfItemAtPath:[NSTemporaryDirectory() stringByAppendingString:file] error:nil] fileSize];
        totalSize += fileSize;
    }
    
    if (totalSize > 0) {
        
        self.filesName = [[NSMutableArray alloc] initWithArray:files];
        [self.shareTable reloadData];
        
    } else {
        
        [self closeShareViewController];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.filesName count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *fileName = [self.filesName objectAtIndex:indexPath.row];
    UIImage *image = nil;
    
    CCCellShareExt *cell = (CCCellShareExt *)[tableView dequeueReusableCellWithIdentifier:@"ShareExtCell" forIndexPath:indexPath];

    CFStringRef fileExtension = (__bridge CFStringRef)[fileName pathExtension];
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);

    if (UTTypeConformsTo(fileUTI, kUTTypeZipArchive) && [(__bridge NSString *)fileUTI containsString:@"org.openxmlformats"] == NO) image = [UIImage imageNamed:@"file_compress"];
    else if (UTTypeConformsTo(fileUTI, kUTTypeAudio)) image = [UIImage imageNamed:@"file_audio"];
    else if (UTTypeConformsTo(fileUTI, kUTTypeMovie)) image = [UIImage imageNamed:@"file_movie"];
    else if (UTTypeConformsTo(fileUTI, kUTTypeImage)) {
        image = [UIImage imageWithContentsOfFile:[NSTemporaryDirectory() stringByAppendingString:fileName]];
        if (image) {
            image = [NCUtility.shared resizeImageWithImage:image toHeight:cell.frame.size.width];
        } else {
            image = [UIImage imageNamed:@"file_photo"];
        }
    }
    else if (UTTypeConformsTo(fileUTI, kUTTypeContent)) {
        
        image = [UIImage imageNamed:@"document"];
        
        NSString *typeFile = (__bridge NSString *)fileUTI;
        
        if ([typeFile isEqualToString:@"com.adobe.pdf"]) image = [UIImage imageNamed:@"file_pdf"];
        if ([typeFile isEqualToString:@"org.openxmlformats.spreadsheetml.sheet"]) image = [UIImage imageNamed:@"file_xls"];
        if ([typeFile isEqualToString:@"public.plain-text"]) image = [UIImage imageNamed:@"file_txt"];
    }
    else image = [UIImage imageNamed:@"file"];
    
    NSUInteger fileSize = (NSInteger)[[[NSFileManager defaultManager] attributesOfItemAtPath:[NSTemporaryDirectory() stringByAppendingString:fileName] error:nil] fileSize];
    
    cell.fileImageView.image = image;

    cell.fileName.text = fileName;
    cell.fileName.textColor = NCBrandColor.sharedInstance.textView;
    cell.fileName.delegate = self;
    
    cell.info.text = [CCUtility transformedSize:fileSize];
    cell.info.textColor = NCBrandColor.sharedInstance.textView;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

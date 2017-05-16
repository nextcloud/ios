//
//  ShareViewController.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 26/01/16.
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

#import "ShareViewController.h"
#import "NCBridgeSwift.h"

@import MobileCoreServices;

@interface ShareViewController ()
{
    NSURL *dirGroup;
    NSUInteger totalSize;
    
    NSExtensionItem *inputItem;
    CCMetadata *saveMetadataPlist;
    
    UIColor *barTintColor;
    UIColor *tintColor;
    
    NSMutableArray *_filesSendCryptated;
    BOOL _isCryptoCloudMode;
}
@end

@implementation ShareViewController

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

-(void)viewDidLoad
{
    dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[NCBrandOptions sharedInstance].capabilitiesGroups];
    
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:(id)[dirGroup URLByAppendingPathComponent:[appDatabase stringByAppendingPathComponent:@"cryptocloud"]]];
    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelOff];

    TableAccount *recordAccount = [CCCoreData getActiveAccount];
    if (recordAccount == nil) {
        
        // close now
        [self performSelector:@selector(closeShareViewController) withObject:nil afterDelay:0.1];
        
        return;
        
    } else {
        
        _activeAccount = recordAccount.account;
        _activePassword = recordAccount.password;
        _activeUrl = recordAccount.url;
        _activeUser = recordAccount.user;
        _directoryUser = [CCUtility getDirectoryActiveUser:self.activeUser activeUrl:self.activeUrl];
        
        if ([[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] == 0) {
            
            _isCryptoCloudMode = NO;
            
        } else {
            
            _isCryptoCloudMode = YES;
        }

        
        if ([_activeAccount isEqualToString:[CCUtility getActiveAccountShareExt]]) {
            
            // load
            
            _serverUrl = [CCUtility getServerUrlShareExt];
            
            _destinyFolderButton.title = [NSString stringWithFormat:NSLocalizedString(@"_destiny_folder_", nil), [CCUtility getTitleServerUrlShareExt]];
            
            if (_isCryptoCloudMode)
                _localCryptated = [CCUtility getCryptatedShareExt];
            
        } else {
            
            // Default settings
            
            [CCUtility setActiveAccountShareExt:self.activeAccount];

            _serverUrl  = [CCUtility getHomeServerUrlActiveUrl:self.activeUrl];
            [CCUtility setServerUrlShareExt:_serverUrl];

            _destinyFolderButton.title = [NSString stringWithFormat:NSLocalizedString(@"_destiny_folder_", nil), NSLocalizedString(@"_home_", nil)];
            [CCUtility setTitleServerUrlShareExt:NSLocalizedString(@"_home_", nil)];

            _localCryptated = NO;
            [CCUtility setCryptatedShareExt:NO];
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
    
    _filesName = [[NSMutableArray alloc] init];
    _filesSendCryptated = [[NSMutableArray alloc] init];
    _hud = [[CCHud alloc] initWithView:self.navigationController.view];
    
    _networkingOperationQueue = [NSOperationQueue new];
    _networkingOperationQueue.name = k_queue;
    _networkingOperationQueue.maxConcurrentOperationCount = 1;
    
    [[CCNetworking sharedNetworking] settingDelegate:self];
        
    [self.shareTable registerNib:[UINib nibWithNibName:@"CCCellShareExt" bundle:nil] forCellReuseIdentifier:@"ShareExtCell"];
    
    [self navigationBarToolBar];
    
    [self loadDataSwift];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // BUGFIX 2.17 - Change user Nextcloud App
    [[CCNetworking sharedNetworking] settingAccount];
    
    if ([[CCUtility getBlockCode] length] > 0 && [CCUtility getOnlyLockDir] == NO)
        [self openBKPasscode];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)closeShareViewController
{
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

//
// L'applicazione terminerà
//
- (void)applicationWillTerminate:(UIApplication *)application
{    
    NSLog(@"[LOG] bye bye, Crypto Cloud Share Extension!");
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Action ==
#pragma --------------------------------------------------------------------------------------------

- (void)navigationBarToolBar
{    
    UIBarButtonItem *rightButtonUpload, *rightButtonEncrypt, *leftButtonCancel;

    // Theming
    tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilitesForAccount:self.activeAccount];
    if ([NCBrandOptions sharedInstance].use_themingColor && capabilities.themingColor.length > 0)
        [NCBrandColor sharedInstance].brand = [CCGraphics colorFromHexString:capabilities.themingColor];

    self.navigationController.navigationBar.barTintColor = [NCBrandColor sharedInstance].brand;
    self.navigationController.navigationBar.tintColor = [NCBrandColor sharedInstance].navigationBarText;
    
    self.toolBar.barTintColor = [NCBrandColor sharedInstance].tabBar;
    self.toolBar.tintColor = [NCBrandColor sharedInstance].brand;
    
    // Upload
    if (self.localCryptated && _isCryptoCloudMode) {
        
        rightButtonUpload = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_save_encrypted_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(selectPost)];
        [rightButtonUpload setTintColor:[NCBrandColor sharedInstance].cryptocloud];
        
    } else {
        
        rightButtonUpload = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_save_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(selectPost)];
    }
    
    // Encrypt ICON
    if (_isCryptoCloudMode) {
        UIImage *icon = [[UIImage imageNamed:@"shareExtEncrypt"] imageWithRenderingMode:UIImageRenderingModeAutomatic];
        rightButtonEncrypt = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(changeEncrypt)];
        if (self.localCryptated) [rightButtonEncrypt setTintColor:[NCBrandColor sharedInstance].cryptocloud];
    }
    
    // Cancel
    leftButtonCancel = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancelPost)];
    
    // Title
    [self.navigationController.navigationBar setTitleTextAttributes: @{NSForegroundColorAttributeName:self.navigationController.navigationBar.tintColor}];
    
    self.navigationItem.title = [NCBrandOptions sharedInstance].brand;
    self.navigationItem.leftBarButtonItem = leftButtonCancel;
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:rightButtonUpload, rightButtonEncrypt, nil];
    self.navigationItem.hidesBackButton = YES;
}

- (void)moveServerUrlTo:(NSString *)serverUrlTo title:(NSString *)title selectedMetadatas:(NSArray *)selectedMetadatas
{
    if (serverUrlTo)
        _serverUrl = serverUrlTo;
    
    if (title) {
        self.destinyFolderButton.title = [NSString stringWithFormat:NSLocalizedString(@"_destiny_folder_", nil), title];
        [CCUtility setTitleServerUrlShareExt:title];
    } else {
        self.destinyFolderButton.title = [NSString stringWithFormat:NSLocalizedString(@"_destiny_folder_", nil), NSLocalizedString(@"_home_", nil)];
        [CCUtility setTitleServerUrlShareExt:NSLocalizedString(@"_home_", nil)];
    }
    
    [CCUtility setActiveAccountShareExt:self.activeAccount];
    [CCUtility setServerUrlShareExt:_serverUrl];
}

- (IBAction)destinyFolderButtonTapped:(UIBarButtonItem *)sender
{
    UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMove"];
    
    CCMove *viewController = (CCMove *)navigationController.topViewController;
    
    viewController.delegate = self;
    viewController.move.title = NSLocalizedString(@"_select_", nil);
    viewController.tintColor = tintColor;
    viewController.barTintColor = barTintColor;
    viewController.tintColorTitle = tintColor;
    viewController.networkingOperationQueue = _networkingOperationQueue;

    [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)selectPost
{
    if ([self.filesName count] > 0) {
    
        NSString *fileName = [self.filesName objectAtIndex:0];
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:_activeAccount];
            
        metadataNet.action = actionUploadFile;
        metadataNet.cryptated = _localCryptated;
        metadataNet.fileName = fileName;
        metadataNet.fileNamePrint = fileName;
        metadataNet.serverUrl = _serverUrl;
        metadataNet.session = k_upload_session_foreground;
        metadataNet.taskStatus = k_taskStatusResume;
        
        [self addNetworkingQueue:metadataNet];
        
        [self.hud visibleHudTitle:NSLocalizedString(@"_uploading_", nil) mode:MBProgressHUDModeDeterminateHorizontalBar color:self.view.tintColor];
       
        [self.hud AddButtonCancelWithTarget:self selector:@"cancelTransfer"];
    }
    else
        [self closeShareViewController];
}

- (void)cancelPost
{
    // rimuoviamo i file+ico
    for (NSString *fileName in self.filesName) {
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", self.directoryUser, fileName] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", self.directoryUser, fileName] error:nil];
    }
    
    [self closeShareViewController];
}

- (void)changeEncrypt
{
    if (self.localCryptated) self.localCryptated = NO;
    else self.localCryptated = YES;
    
    [CCUtility setCryptatedShareExt:self.localCryptated];

    [self navigationBarToolBar];
}

- (void)cancelTransfer
{
    [_networkingOperationQueue cancelAllOperations];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ======================= NetWorking ==================================
#pragma --------------------------------------------------------------------------------------------

- (void)triggerProgressTask:(NSNotification *)notification
{
    NSDictionary *dict = notification.userInfo;
    float progress = [[dict valueForKey:@"progress"] floatValue];

    [self.hud progress:progress];
}

- (void)uploadFileFailure:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [self.hud hideHud];
    
    // remove file 
    [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, _activeAccount]];
    
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", _directoryUser, fileID] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", _directoryUser, fileID] error:nil];

    // message error
    if (errorCode != kCFURLErrorCancelled) {
        
        UIAlertController * alert= [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       [alert dismissViewControllerAnimated:YES completion:nil];
                                                       [self closeShareViewController];
                                                   }];
        [alert addAction:ok];
        [self presentViewController:alert animated:YES completion:nil];
    }
    else
        [self closeShareViewController];
}

- (void)uploadFileSuccess:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    [self.hud hideHud];
    
    CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, _activeAccount] context:nil];
        
    [self.filesName removeObject:metadata.fileNamePrint];
    [self.shareTable performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
    
    [self performSelector:@selector(selectPost) withObject:nil afterDelay:0.1];
}

- (void)addNetworkingQueue:(CCMetadataNet *)metadataNet
{
    id operation;
   
    operation = [[OCnetworking alloc] initWithDelegate:self metadataNet:metadataNet withUser:_activeUser withPassword:_activePassword withUrl:_activeUrl isCryptoCloudMode:_isCryptoCloudMode];
    
    [operation setQueuePriority:metadataNet.priority];
    
    [_networkingOperationQueue addOperation:operation];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Lock Password =====
#pragma --------------------------------------------------------------------------------------------

- (void)openBKPasscode
{
    CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
    viewController.delegate = self;
    viewController.type = BKPasscodeViewControllerCheckPasscodeType;
    viewController.inputViewTitlePassword = YES;
    
    if ([CCUtility getSimplyBlockCode]) {
        
        viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
        viewController.passcodeInputView.maximumLength = 6;
        
    } else {
        
        viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
        viewController.passcodeInputView.maximumLength = 64;
    }
    
    BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
    touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
    viewController.touchIDManager = touchIDManager;
    viewController.title = [NCBrandOptions sharedInstance].brand;
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
    viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navController animated:YES completion:nil];
}

- (NSUInteger)passcodeViewControllerNumberOfFailedAttempts:(CCBKPasscode *)aViewController
{
    return self.failedAttempts;
}

- (NSDate *)passcodeViewControllerLockUntilDate:(CCBKPasscode *)aViewController
{
    return self.lockUntilDate;
}

- (void)passcodeViewCloseButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self performSelector:@selector(closeShareViewController) withObject:nil];
    }];
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if ([aPasscode isEqualToString:[CCUtility getBlockCode]]) {
        self.lockUntilDate = nil;
        self.failedAttempts = 0;
        aResultHandler(YES);
    } else aResultHandler(NO);
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    [aViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Swipe Table DELETE -> menu =====
#pragma--------------------------------------------------------------------------------------------

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self setEditing:NO animated:YES];
    
    NSString *fileName = [self.filesName objectAtIndex:indexPath.row];
    
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", self.directoryUser, fileName] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", self.directoryUser, fileName] error:nil];

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
    
    [loadItem loadFiles:self.directoryUser extensionContext:self.extensionContext vc:self];
}

- (void)reloadData:(NSArray *)files
{
    totalSize = 0;

    for (NSString *file in files) {
        
        NSUInteger fileSize = (NSInteger)[[[NSFileManager defaultManager] attributesOfItemAtPath:[NSString stringWithFormat:@"%@/%@", self.directoryUser, file] error:nil] fileSize];
        
        totalSize += fileSize;
        
        // creiamo l'ICO
        CFStringRef fileExtension = (__bridge CFStringRef)[file pathExtension];
        CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
        
        if (fileSize > 0 && ((UTTypeConformsTo(fileUTI, kUTTypeImage)) || (UTTypeConformsTo(fileUTI, kUTTypeMovie)))) {
            
            NSString *typeFile;
            if (UTTypeConformsTo(fileUTI, kUTTypeImage)) typeFile = k_metadataTypeFile_image;
            if (UTTypeConformsTo(fileUTI, kUTTypeMovie)) typeFile = k_metadataTypeFile_video;
            
            [CCGraphics createNewImageFrom:file directoryUser:self.directoryUser fileNameTo:file fileNamePrint:nil size:@"m" imageForUpload:NO typeFile:typeFile writePreview:YES optimizedFileName:NO];
        }
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
    
    CFStringRef fileExtension = (__bridge CFStringRef)[fileName pathExtension];
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);

    if (UTTypeConformsTo(fileUTI, kUTTypeZipArchive) && [(__bridge NSString *)fileUTI containsString:@"org.openxmlformats"] == NO) image = [UIImage imageNamed:@"file_compress"];
    else if (UTTypeConformsTo(fileUTI, kUTTypeAudio)) image = [UIImage imageNamed:@"file_audio"];
    else if ((UTTypeConformsTo(fileUTI, kUTTypeImage)) || (UTTypeConformsTo(fileUTI, kUTTypeMovie))) {
        
        image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", self.directoryUser, fileName]];
        
    }
    else if (UTTypeConformsTo(fileUTI, kUTTypeContent)) {
        
        image = [UIImage imageNamed:@"document"];
        
        NSString *typeFile = (__bridge NSString *)fileUTI;
        
        if ([typeFile isEqualToString:@"com.adobe.pdf"]) image = [UIImage imageNamed:@"file_pdf"];
        if ([typeFile isEqualToString:@"org.openxmlformats.spreadsheetml.sheet"]) image = [UIImage imageNamed:@"file_xls"];
        if ([typeFile isEqualToString:@"public.plain-text"]) image = [UIImage imageNamed:@"file_txt"];
    }
    else image = [UIImage imageNamed:@"file"];
    
    CCCellShareExt *cell = (CCCellShareExt *)[tableView dequeueReusableCellWithIdentifier:@"ShareExtCell" forIndexPath:indexPath];
    
    NSUInteger fileSize = (NSInteger)[[[NSFileManager defaultManager] attributesOfItemAtPath:[NSString stringWithFormat:@"%@/%@", self.directoryUser, fileName] error:nil] fileSize];
    
    cell.labelInformazioni.text = [NSString stringWithFormat:@"%@\r\r%@", fileName, [CCUtility transformedSize:fileSize]];
    cell.labelInformazioni.textColor = [UIColor blackColor];

    cell.fileImageView.image = image;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

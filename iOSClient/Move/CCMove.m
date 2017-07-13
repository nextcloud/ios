//
//  CCMove.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
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

#import "CCMove.h"
#import "NCBridgeSwift.h"

@interface CCMove ()
{    
    NSString *activeAccount;
    NSString *activePassword;
    NSString *activeUrl;
    NSString *activeUser;
    NSString *directoryUser;
    
    BOOL _isCryptoCloudMode;
    
    BOOL _loadingFolder;
}
@end

@implementation CCMove

// MARK: - View

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (recordAccount) {
        
        activeAccount = recordAccount.account;
        activePassword = recordAccount.password;
        activeUrl = recordAccount.url;
        activeUser = recordAccount.user;
        directoryUser = [CCUtility getDirectoryActiveUser:activeUser activeUrl:activeUrl];
        
        // Crypto Mode
        if ([[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] == 0) {
            
            _isCryptoCloudMode = NO;
            
        } else {
            
            _isCryptoCloudMode = YES;
        }
        
    } else {
        
        UIAlertController * alert= [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"_no_active_account_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];
        [alert addAction:ok];
        [self presentViewController:alert animated:YES completion:nil];
    }
    
    [self.cancel setTitle:NSLocalizedString(@"_cancel_", nil)];
    [self.create setTitle:NSLocalizedString(@"_create_folder_", nil)];

    if (![_serverUrl length]) {
        
        _serverUrl = [CCUtility getHomeServerUrlActiveUrl:activeUrl];
        UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed: @"navigationLogo"]];
        [self.navigationController.navigationBar.topItem setTitleView:image];
        self.title = @"Home";
        
    } else {
        
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0,0, self.navigationItem.titleView.frame.size.width, 40)];
        label.text = self.passMetadata.fileNamePrint;
        
        if (self.passMetadata.cryptated) label.textColor = NCBrandColor.sharedInstance.cryptocloud;
        else label.textColor = NCBrandColor.sharedInstance.navigationBarText;
        
        label.backgroundColor =[UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        self.navigationItem.titleView=label;
    }
    
    // TableView : at the end of rows nothing
    self.tableView.tableFooterView = [UIView new];
    self.tableView.separatorColor =  NCBrandColor.sharedInstance.seperator;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;

    // read file->folder
    [self readFileReloadFolder];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand;
    self.navigationController.navigationBar.tintColor = NCBrandColor.sharedInstance.navigationBarText;
    
    self.navigationController.toolbar.barTintColor = NCBrandColor.sharedInstance.tabBar;
    self.navigationController.toolbar.tintColor = NCBrandColor.sharedInstance.brand;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)emptyDataSetShouldDisplay:(UIScrollView *)scrollView
{
    if (_loadingFolder)
        return YES;
    else
        return NO;
}

- (BOOL)emptyDataSetShouldAllowScroll:(UIScrollView *)scrollView
{
    return NO;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIColor whiteColor];
}

- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView
{
    if (_loadingFolder) {
        
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
        activityView.color = [NCBrandColor sharedInstance].brand;
        [activityView startAnimating];
        
        return activityView;
    }
    
    return nil;
}

// MARK: - IBAction

- (IBAction)cancel:(UIBarButtonItem *)sender
{
    if ([self.delegate respondsToSelector:@selector(dismissMove)])
        [self.delegate dismissMove];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)move:(UIBarButtonItem *)sender
{
    [_networkingOperationQueue cancelAllOperations];
 
    if ([self.delegate respondsToSelector:@selector(dismissMove)])
        [self.delegate dismissMove];
    
    [self.delegate moveServerUrlTo:_serverUrl title:self.passMetadata.fileNamePrint];
        
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)create:(UIBarButtonItem *)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_create_folder_",nil) message:@"" preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        //textField.placeholder = NSLocalizedString(@"LoginPlaceholder", @"Login");
        textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_save_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self createFolder:alertController.textFields.firstObject.text];
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

// MARK: - BKPasscodeViewController

- (void)passcodeViewController:(CCBKPasscode *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    [aViewController dismissViewControllerAnimated:YES completion:nil];
    
    [self performSegueDirectoryWithControlPasscode:false];
}

- (void)passcodeViewController:(BKPasscodeViewController *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if ([aPasscode isEqualToString:[CCUtility getBlockCode]]) {
        
        self.lockUntilDate = nil;
        self.failedAttempts = 0;
        aResultHandler(YES);
        
    } else {
        
        aResultHandler(NO);
    }
}

- (void)passcodeViewControllerDidFailAttempt:(BKPasscodeViewController *)aViewController
{
    self.failedAttempts++;
    
    if (self.failedAttempts > 5) {
        
        NSTimeInterval timeInterval = 60;
        
        if (self.failedAttempts > 6) {
            
            NSUInteger multiplier = self.failedAttempts - 6;
            
            timeInterval = (5 * 60) * multiplier;
            
            if (timeInterval > 3600 * 24) {
                timeInterval = 3600 * 24;
            }
        }
        
        self.lockUntilDate = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
    }
}

- (NSUInteger)passcodeViewControllerNumberOfFailedAttempts:(BKPasscodeViewController *)aViewController
{
    return self.failedAttempts;
}

- (NSDate *)passcodeViewControllerLockUntilDate:(BKPasscodeViewController *)aViewController
{
    return self.lockUntilDate;
}

- (void)passcodeViewCloseButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - NetWorking

- (void)addNetworkingQueue:(CCMetadataNet *)metadataNet
{
    OCnetworking *operation = [[OCnetworking alloc] initWithDelegate:self metadataNet:metadataNet withUser:activeUser withPassword:activePassword withUrl:activeUrl isCryptoCloudMode:_isCryptoCloudMode];
        
    _networkingOperationQueue.maxConcurrentOperationCount = k_maxConcurrentOperation;
    [_networkingOperationQueue addOperation:operation];
}

// MARK: - Download File

- (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    if ([selector isEqualToString:selectorLoadPlist]) {

        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
        metadata = [CCUtility insertInformationPlist:metadata directoryUser:directoryUser];
        metadata = [[NCManageDatabase sharedInstance] updateMetadata:metadata activeUrl:activeUrl];
        
        // se è un template aggiorniamo anche nel FileSystem
        if ([metadata.type isEqualToString: k_metadataType_template]) {
            [[NCManageDatabase sharedInstance] setLocalFileWithFileID:metadata.fileID date:metadata.date exifDate:nil exifLatitude:nil exifLongitude:nil fileName:nil fileNamePrint:metadata.fileNamePrint];
        }

        [self.tableView reloadData];
    }
}

- (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    self.move.enabled = NO;
}

// MARK: - Read Folder

- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [self readFolder];
}

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(tableMetadata *)metadata
{
    if ([metadataNet.selector isEqualToString:selectorReadFileReloadFolder]) {
        
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", metadataNet.account, metadataNet.serverUrl]];
        
        if ([metadata.etag isEqualToString:directory.etag] == NO) {
            
            [self readFolder];
        }
    }
}

- (void)readFileReloadFolder
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:activeAccount];
    
    metadataNet.action = actionReadFile;
    metadataNet.priority = NSOperationQueuePriorityHigh;
    metadataNet.selector = selectorReadFileReloadFolder;
    metadataNet.serverUrl = _serverUrl;
    
    [self addNetworkingQueue:metadataNet];
}

// MARK: - Read Folder

- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    _loadingFolder = NO;
    self.move.enabled = NO;
    
    [self.tableView reloadData];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_",nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)readFolderSuccess:(CCMetadataNet *)metadataNet metadataFolder:(tableMetadata *)metadataFolder metadatas:(NSArray *)metadatas
{
    NSMutableArray *metadatasToInsertInDB = [NSMutableArray new];
 
    // Update directory etag
    [[NCManageDatabase sharedInstance] setDirectoryWithServerUrl:metadataNet.serverUrl serverUrlTo:nil etag:metadataFolder.etag];
    
    for (tableMetadata *metadata in metadatas) {
        
        // type of file
        NSInteger typeFilename = [CCUtility getTypeFileName:metadata.fileName];
        
        // do not insert crypto file
        if (typeFilename == k_metadataTypeFilenameCrypto) continue;
        
        // verify if the record encrypted has plist + crypto
        if (typeFilename == k_metadataTypeFilenamePlist && metadata.directory == NO) {
            
            BOOL isCryptoComplete = NO;
            NSString *fileNameCrypto = [CCUtility trasformedFileNamePlistInCrypto:metadata.fileName];
            
            for (tableMetadata *completeMetadata in metadatas) {
                
                if (completeMetadata.cryptated == NO) continue;
                else  if ([completeMetadata.fileName isEqualToString:fileNameCrypto]) {
                    isCryptoComplete = YES;
                    break;
                }
            }
            if (isCryptoComplete == NO) continue;
        }
    
        // Insert in Array
        [metadatasToInsertInDB addObject:metadata];
    }

    // insert in Database
    metadatas = [[NCManageDatabase sharedInstance] addMetadatas:metadatasToInsertInDB activeUrl:activeUrl serverUrl:metadataNet.serverUrl];

    // Plist MULTI THREAD
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        for (tableMetadata *metadata in metadatas) {
        
            if ([CCUtility isCryptoPlistString:metadata.fileName] && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, metadata.fileName]] == NO) {
                
                CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:activeAccount];
                    
                metadataNet.action = actionDownloadFile;
                metadataNet.downloadData = NO;
                metadataNet.downloadPlist = YES;
                metadataNet.fileID = metadata.fileID;
                metadataNet.selector = selectorLoadPlist;
                metadataNet.serverUrl = _serverUrl;
                metadataNet.session = k_download_session_foreground;
                metadataNet.taskStatus = k_taskStatusResume;
                    
                [self addNetworkingQueue:metadataNet];
            }
        }
    });    
    
    _loadingFolder = NO;
    [self.tableView reloadData];
}

- (void)readFolder
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.serverUrl = _serverUrl;
    metadataNet.selector = selectorReadFolder;
    metadataNet.date = nil;
    
    [self addNetworkingQueue:metadataNet];
    
    //
    _loadingFolder = YES;
    [self.tableView reloadData];
}

// MARK: - Create Folder

- (void)createFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_",nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)createFolderSuccess:(CCMetadataNet *)metadataNet
{
    (void)[[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:[NSString stringWithFormat:@"%@/%@", metadataNet.serverUrl, metadataNet.fileName] permissions:@""];
    
    // Load Folder or the Datasource
    [self readFolder];
}

- (void)createFolder:(NSString *)fileNameFolder
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:activeAccount];
    
    fileNameFolder = [CCUtility removeForbiddenCharactersServer:fileNameFolder];
    if (![fileNameFolder length]) return;
    
    metadataNet.action = actionCreateFolder;
    metadataNet.fileName = fileNameFolder;
    metadataNet.selector = selectorCreateFolder;
    metadataNet.selectorPost = selectorReadFolderForced;
    metadataNet.serverUrl = _serverUrl;
    
    [self addNetworkingQueue:metadataNet];
}

// MARK: - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];
    NSPredicate *predicate;
    
    if (self.onlyClearDirectory) predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND directory = true AND cryptated = false", activeAccount, directoryID];
    else predicate = [NSPredicate predicateWithFormat:@"account == %@ AND directoryID = %@ AND directory = true", activeAccount, directoryID];
    
    NSArray *result = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:predicate sorted:nil ascending:NO];
    
    if (result)
        return [result count];
    else
        return 0;    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSPredicate *predicate;
    
    static NSString *CellIdentifier = @"MyCustomCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];
    
    if (self.onlyClearDirectory) predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND directory = true AND cryptated = false", activeAccount, directoryID];
    else predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND directory = true", activeAccount, directoryID];
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataAtIndexWithPredicate:predicate sorted:@"fileNamePrint" ascending:YES index:indexPath.row];
    
    // colors
    if (metadata.cryptated) {
        cell.textLabel.textColor = NCBrandColor.sharedInstance.cryptocloud;
    } else {
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    cell.detailTextLabel.text = @"";
    cell.imageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:metadata.iconName] color:[NCBrandColor sharedInstance].brand];
    cell.textLabel.text = metadata.fileNamePrint;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self performSegueDirectoryWithControlPasscode:YES];
}

// MARK: - Navigation

- (void)performSegueDirectoryWithControlPasscode:(BOOL)controlPasscode
{
    NSString *nomeDir;
    NSPredicate *predicate;

    NSIndexPath *index = [self.tableView indexPathForSelectedRow];
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];
    
    if (self.onlyClearDirectory) predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND directory = true AND cryptated = false", activeAccount, directoryID];
    else predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID == %@ AND directory = true", activeAccount, directoryID];
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataAtIndexWithPredicate:predicate sorted:@"fileNamePrint" ascending:YES index:index.row];
    
    if (metadata.errorPasscode == NO) {
    
        // lockServerUrl
        NSString *lockServerUrl = [CCUtility stringAppendServerUrl:_serverUrl addFileName:metadata.fileNameData];
        
        // Se siamo in presenza di una directory bloccata E è attivo il block E la sessione PASSWORD Lock è senza data ALLORA chiediamo la password per procedere
        
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", activeAccount, lockServerUrl]];
        
        if (directory.lock && [[CCUtility getBlockCode] length] && controlPasscode) {
            
            CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
            viewController.delegate = self;
            //viewController.fromType = CCBKPasscodeFromLockDirectory;
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
            
            viewController.title = NSLocalizedString(@"_folder_blocked_", nil);
            viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
            viewController.navigationItem.leftBarButtonItem.tintColor = NCBrandColor.sharedInstance.cryptocloud;
            
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            [self presentViewController:navController animated:YES completion:nil];
            
            return;
        }
        
        if (metadata.cryptated) nomeDir = [metadata.fileName substringToIndex:[metadata.fileName length]-6];
        else nomeDir = metadata.fileName;
    
        CCMove *viewController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMoveVC"];
    
        viewController.delegate = self.delegate;
        viewController.onlyClearDirectory = self.onlyClearDirectory;
        viewController.move.title = self.move.title;
        viewController.networkingOperationQueue = _networkingOperationQueue;

        viewController.passMetadata = metadata;
        viewController.serverUrl = [CCUtility stringAppendServerUrl:_serverUrl addFileName:nomeDir];
    
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

@end

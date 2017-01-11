//
//  CCMain.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
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

#import "CCMain.h"

#import "AppDelegate.h"
#import "CCPhotosCameraUpload.h"
#import "CCSynchronization.h"

#import "Nextcloud-Swift.h"

#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

#define alertCreateFolder 1
#define alertCreateFolderCrypto 2
#define alertRename 3
#define alertSynchronization 4

@interface CCMain ()
{
    CCMetadata *_metadataSegue;
    CCMetadata *_metadata;
        
    BOOL _isMain;
    BOOL _isViewDidLoad;
    
    NSString *_localDirectoryID;

    BOOL _isPickerCriptate;              // if is cryptated image or video back from picker
    BOOL _isSelectedMode;
    long _numTaskUploadInProgress;
    
    NSMutableArray *_selectedMetadatas;
    NSMutableArray *_queueSelector;
    NSUInteger _numSelectedMetadatas;
    UIImageView *_ImageTitleHomeCryptoCloud;
    UIView *_reMenuBackgroundView;
    UITapGestureRecognizer *_singleFingerTap;
    
    NSString *_directoryGroupBy;
    NSString *_directoryOrder;
    
    NSUInteger _failedAttempts;
    NSDate *_lockUntilDate;

    NSString *_fatherPermission;

    UIRefreshControl *_ccRefreshControl;
    UIDocumentInteractionController *_docController;

    CCHud *_hud;
    CCHud *_hudDeterminate;
    
    // Datasource
    CCSectionDataSource *_sectionDataSource;
    NSDate *_dateReadDataSource;
}
@end

@implementation CCMain

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{    
    if (self = [super initWithCoder:aDecoder])  {
        
        _directoryOrder = [CCUtility getOrderSettings];
        _directoryGroupBy = [CCUtility getGroupBySettings];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initializeMain:) name:@"initializeMain" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearDateReadDataSource:) name:@"clearDateReadDataSource" object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setTitleNOAnimation) name:@"setTitleCCMainNOAnimation" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setTitleYESAnimation) name:@"setTitleCCMainYESAnimation" object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readFileSelfFolderRev) name:@"readFileSelfFolderRev" object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getDataSourceWithReloadTableView) name:@"getDataSourceWithReloadTableView" object:nil];
    }
    
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // init object
    _metadata = [[CCMetadata alloc] init];
    _metadataSegue = [[CCMetadata alloc] init];
    _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    _hudDeterminate = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    _selectedMetadatas = [[NSMutableArray alloc] init];
    _queueSelector = [[NSMutableArray alloc] init];
    _isViewDidLoad = YES;

    // delegate
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.separatorColor = COLOR_SEPARATOR_TABLE;

    [[CCNetworking sharedNetworking] settingDelegate:self];
    
    // Custom Cell
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMain" bundle:nil] forCellReuseIdentifier:@"CellMain"];
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMainTransfer" bundle:nil] forCellReuseIdentifier:@"CellMainTransfer"];
    
    // long press recognizer TableView
    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressTableView:)];
    [self.tableView addGestureRecognizer:longPressRecognizer];
    
    // Pull-to-Refresh
    _ccRefreshControl = [[UIRefreshControl alloc] init];
    _ccRefreshControl.tintColor = COLOR_BRAND;
    [_ccRefreshControl addTarget:self action:@selector(refreshControlTarget) forControlEvents:UIControlEventValueChanged];
    [self setRefreshControl:_ccRefreshControl];

    // Register for 3D Touch Previewing if available
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] && (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable))
    {
        [self registerForPreviewingWithDelegate:self sourceView:self.view];
    }

    // Back Button
    if ([_localServerUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:app.activeUrl typeCloud:app.typeCloud]])
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:image_brandNavigationController] style:UIBarButtonItemStylePlain target:nil action:nil];
    
    // reMenu Background
    _reMenuBackgroundView = [[UIView alloc] init];
    _reMenuBackgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    
    // if this is not Main (the Main uses inizializeMain)
    if (_isMain == NO && app.activeAccount) {
        
        // Settings this folder & delegate & Loading datasource
        app.serverUrl = _localServerUrl;
        app.directoryUser = [CCUtility getDirectoryActiveUser:app.activeUser activeUrl:app.activeUrl];
        _localDirectoryID = [CCCoreData getDirectoryIDFromServerUrl:_localServerUrl activeAccount:app.activeAccount];
        
        // Load Datasource
        [self getDataSourceWithReloadTableView:_localDirectoryID fileID:nil selector:nil];
        
        // Read Folder
        [self readFolderWithForced:NO];
    }

    // Title
    [self setTitleNOAnimation];
        
    // List Transfers
    app.controlCenter = (CCControlCenter *)self.navigationController;
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Settings this folder & delegate & Loading datasource
    if (app.activeAccount) {
        app.serverUrl = _localServerUrl;
        app.directoryUser = [CCUtility getDirectoryActiveUser:app.activeUser activeUrl:app.activeUrl];
        _localDirectoryID = [CCCoreData getDirectoryIDFromServerUrl:_localServerUrl activeAccount:app.activeAccount];
    }
    [[CCNetworking sharedNetworking] settingDelegate:self];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Menu e Bar
    [self createReMainMenu];
    [self createReSelectMenu];
    if (_isSelectedMode) [self setUINavigationBarSeleziona];
    else [self setUINavigationBarDefault];
    
    // Plus Button
    [app plusButtonVisibile:true];
}

// E' arrivato
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Active Main
    app.activeMain = self;
    
    // Test viewDidLoad
    if (_isViewDidLoad) {
        
        _isViewDidLoad = NO;
        
    } else {
        
        if (app.activeAccount) {
            
            // Load Datasource
            [self getDataSourceWithReloadTableView:_localDirectoryID fileID:nil selector:nil];
            
            // Read Folder
            [self readFolderWithForced:NO];
        }
    }

    // Title
    [self setTitle];
    
    // cancell Progress
    [self.navigationController cancelCCProgress];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Close MainMenu & SelectMenu
    if (app.reMainMenu.isOpen || app.reSelectMenu.isOpen) {
        
        [app.reMainMenu close];
        [app.reSelectMenu close];
    }
    
    // Close Menu change user
    [CCMenu dismissMenu];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.    
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Initizlize Mail =====
#pragma --------------------------------------------------------------------------------------------

- (void)initializeMain:(NSNotification *)notification
{
    _directoryGroupBy = nil;
    _directoryOrder = nil;
    _dateReadDataSource = nil;
    
    // test
    if ([app.activeAccount length] == 0 || [app.activeUrl length] == 0 || [app.typeCloud length] == 0)
        return;
    
    if ([app.listMainVC count] == 0 || _isMain) {
        
        // This is Main
        _isMain = YES;
        
        // go Home
        [self.navigationController popToRootViewControllerAnimated:NO];
        
        _localServerUrl = [CCUtility getHomeServerUrlActiveUrl:app.activeUrl typeCloud:app.typeCloud];
        _localDirectoryID = [CCCoreData getDirectoryIDFromServerUrl:_localServerUrl activeAccount:app.activeAccount];
        _isFolderEncrypted = NO;
        
        app.serverUrl = _localServerUrl;
        app.directoryUser = [CCUtility getDirectoryActiveUser:app.activeUser activeUrl:app.activeUrl];
    
        // add list
        [app.listMainVC setObject:self forKey:_localServerUrl];
    
        // setting Networking
        [[CCNetworking sharedNetworking] settingDelegate:self];
        [[CCNetworking sharedNetworking] settingAccount];
        
        // populate shared Link & User variable
        [CCCoreData populateSharesVariableFromDBActiveAccount:app.activeAccount sharesLink:app.sharesLink sharesUserAndGroup:app.sharesUserAndGroup];
        
        // Load Datasource
        [self getDataSourceWithReloadTableView:_localDirectoryID fileID:nil selector:nil];

        // Load Folder
        [self readFolderWithForced:NO];
        
        // Load photo datasorce
        if (app.activeAccount && app.activeUrl && app.activePhotosCameraUpload)
            [app.activePhotosCameraUpload reloadDatasourceForced];
        
        // remove all of detail
        if (app.activeDetail)
            [app.activeDetail removeAllView];
        
        // home main
        app.homeMain = self;
        
        // Initializations
        [app applicationInitialized];
        
    } else {
        
        // reload datasource
        [self getDataSourceWithReloadTableView:_localDirectoryID fileID:nil selector:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== AlertView =====
#pragma --------------------------------------------------------------------------------------------

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
        
    if (alertView.tag == alertCreateFolder && buttonIndex == 1) [self createFolder:[alertView textFieldAtIndex:0].text folderCameraUpload:NO];
    
    if (alertView.tag == alertCreateFolderCrypto && buttonIndex == 1) [self createFolderEncrypted:[alertView textFieldAtIndex:0].text];
    
    if (alertView.tag == alertRename && buttonIndex == 1) {
     
        if ([_metadata.model isEqualToString:@"note"]) {
        
            [self renameNote:_metadata fileName:[alertView textFieldAtIndex:0].text];
            
        } else {
            
            [self renameFile:_metadata fileName:[alertView textFieldAtIndex:0].text];
        }
    }
    if (alertView.tag == alertSynchronization && buttonIndex == 1) {
     
        [[CCSynchronization sharedSynchronization] synchronizationFolder:[CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:_metadata.fileNameData]];
        [self performSelector:@selector(getDataSourceWithReloadTableView) withObject:nil afterDelay:0.5];
    }
}

// accept only number char > 0
- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView
{
    /* Retrieve a text field at an index -
     raises NSRangeException when textFieldIndex is out-of-bounds.
     
     The field at index 0 will be the first text field
     (the single field or the login field),
     
     The field at index 1 will be the password field. */
    
    /*
     1> Get the Text Field in alertview
     
     2> Get the text of that Text Field
     
     3> Verify that text length
     
     4> return YES or NO Based on the length
     */
    
    if (alertView.tag == alertSynchronization) return YES;
    else return ([[[alertView textFieldAtIndex:0] text] length]>0)?YES:NO;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Graphic Window =====
#pragma --------------------------------------------------------------------------------------------

- (void)refreshControlTarget
{
    [self readFolderWithForced:YES];
    
    // Actuate `Peek` feedback (weak boom)
    AudioServicesPlaySystemSound(1519);
    
    [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:NO];
}

- (void)setTitleNOAnimation
{
    app.isTitleBrandAnimated = NO;

    [self setTitle];
}

- (void)setTitleYESAnimation
{
    app.isTitleBrandAnimated = YES;
    
    [self setTitle];
}

- (void)setTitle
{
    // PopGesture in progress [swipe gesture to switch between views]
    if (app.controlCenter.isPopGesture)
        return;

    // Color text self.navigationItem.title
    if ([app.reachability isReachable] == NO)
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : COLOR_NO_CONNECTION}];
    else if (_isFolderEncrypted)
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : COLOR_ENCRYPTED}];
    else
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : COLOR_GRAY}];

    //if (self.tableView.isEditing) {
    if (_isSelectedMode) {
        
        NSUInteger totali = [_sectionDataSource.allRecordsDataSource count];
        NSUInteger selezionati = [[self.tableView indexPathsForSelectedRows] count];
        
        self.navigationItem.titleView = nil;
        self.navigationItem.title = [NSString stringWithFormat:@"%@ : %lu / %lu", NSLocalizedString(@"_selected_", nil), (unsigned long)selezionati, (unsigned long)totali];

    } else {
        
        // we are in home
        if ([_localServerUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:app.activeUrl typeCloud:app.typeCloud]]) {
            
            self.navigationItem.title = nil;
            
            if (app.isTitleBrandAnimated) {
                
                NSArray *animationArray = [NSArray arrayWithObjects:[UIImage imageNamed:image_brandNavigationController1],[UIImage imageNamed:image_brandNavigationController2],[UIImage imageNamed:image_brandNavigationController3],[UIImage imageNamed:image_brandNavigationController2],nil];

                _ImageTitleHomeCryptoCloud.animationImages = animationArray;
                _ImageTitleHomeCryptoCloud.animationDuration = 0.9;
                _ImageTitleHomeCryptoCloud.animationRepeatCount = -1;
                
                [_ImageTitleHomeCryptoCloud startAnimating];
                
            } else {
                
                if ([app.reachability isReachable] == NO) _ImageTitleHomeCryptoCloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:image_brandNavigationControllerOffline]];
                else _ImageTitleHomeCryptoCloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:image_brandNavigationController]];
            }
            
            [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
            UITapGestureRecognizer *singleTap =  [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(menuChangeUser)];
            [singleTap setNumberOfTapsRequired:1];
            [_ImageTitleHomeCryptoCloud addGestureRecognizer:singleTap];
            
            self.navigationItem.titleView = _ImageTitleHomeCryptoCloud;
            
        } else {
        
            self.navigationItem.title = _titleMain;
        }
    }
}

- (void)setTitleBackgroundTableView
{
    if ([_sectionDataSource.allRecordsDataSource count] == 0) {
        
        [self setTitleBackgroundTableView:NSLocalizedString(@"_no_file_pull_down_", nil)];
        
    } else {
        
        [self setTitleBackgroundTableView:nil];
    }

}

- (void)setTitleBackgroundTableView:(NSString *)title
{
    if (title) {
        // message if table is empty
        UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
        if ([app.reachability isReachable] == NO) {
            messageLabel.text = NSLocalizedString(@"_comm_erro_pull_down_", nil);
            messageLabel.textColor = COLOR_NO_CONNECTION;
            messageLabel.font = RalewayLight(14.0f);
        } else {
            messageLabel.text = NSLocalizedString(title ,nil);
            messageLabel.textColor = [UIColor blackColor];
            messageLabel.font = RalewayLight(14.0f);
        }
        messageLabel.numberOfLines = 0;
        messageLabel.textAlignment = NSTextAlignmentCenter;
        [messageLabel sizeToFit];
        [self.tableView reloadData];
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.backgroundView = messageLabel;
    } else {
        [self.tableView setBackgroundView:nil];
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
}

- (void)setUINavigationBarDefault
{
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    
    // =
    UIImage *icon = [UIImage imageNamed:image_more];
    UIBarButtonItem *buttonMore = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(toggleReMainMenu)];
    buttonMore.enabled = true;
    
    // <
    self.navigationController.navigationBar.hidden = NO;
    //self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonAdd, buttonMore, nil];
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonMore, nil];

    self.navigationItem.leftBarButtonItem = nil;
    
    // close Menu
    [app.reSelectMenu close];
}

- (void)setUINavigationBarSeleziona
{
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    
    UIImage *icon = [UIImage imageNamed:image_more];
    UIBarButtonItem *buttonMore = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(toggleReSelectMenu)];

    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancelSelect)];
    
    self.navigationItem.leftBarButtonItem = leftButton;
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonMore, nil];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    // close the menus
    if (app.reMainMenu.isOpen)
        [app.reMainMenu close];
    
    if (app.reSelectMenu.isOpen)
        [app.reSelectMenu close];
    
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
    }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)cancelSelect
{
    [self tableViewSelect:NO];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Document Picker =====
#pragma --------------------------------------------------------------------------------------------

- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu
{
    NSLog(@"Cancelled");
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    NSLog(@"Cancelled");
}

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker
{
    documentPicker.delegate = self;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    if (controller.documentPickerMode == UIDocumentPickerModeImport) {
        
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block NSError *error;
        
        [coordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL *newURL) {
            
            NSString *fileName = [url lastPathComponent];
            NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@", app.directoryUser, fileName];
            NSData *data = [NSData dataWithContentsOfURL:newURL];
            
            if (data && error == nil) {
                
                if ([data writeToFile:fileNamePath options:NSDataWritingAtomic error:&error]) {
                    
                    // Upload File
                    [[CCNetworking sharedNetworking] uploadFile:fileName serverUrl:self.localServerUrl cryptated:_isPickerCriptate onlyPlist:NO session:upload_session taskStatus:taskStatusResume selector:nil selectorPost:nil parentRev:nil errorCode:0 delegate:nil];
                    
                } else {
                    
                    [app messageNotification:@"_error_" description:error.description visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
                }
                
            } else {
                
                [app messageNotification:@"_error_" description:@"_read_file_error_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
            }
        }];
    }
}

- (void)openImportDocumentPicker
{
    UIDocumentMenuViewController *documentProviderMenu = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    documentProviderMenu.modalPresentationStyle = UIModalPresentationFormSheet;
    
    documentProviderMenu.delegate = self;
    [self presentViewController:documentProviderMenu animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Assets Picker =====
#pragma --------------------------------------------------------------------------------------------

- (void)openAssetsPickerController
{
    
#ifdef DEBUG
    
    CreateFormUpload *form = [[CreateFormUpload alloc] init:_titleMain];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:form];
    
    //navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;

    [self presentViewController:navController animated:YES completion:nil];

    return;
#endif
    
    CTAssetSelectionLabel *assetSelectionLabel = [CTAssetSelectionLabel appearance];
    assetSelectionLabel.borderWidth = 1.0;
    assetSelectionLabel.borderColor = COLOR_BRAND;
    [assetSelectionLabel setMargin:2.0];
    [assetSelectionLabel setTextAttributes:@{NSFontAttributeName : [UIFont systemFontOfSize:12.0], NSForegroundColorAttributeName : [UIColor whiteColor], NSBackgroundColorAttributeName : COLOR_BRAND}];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // init picker
            CTAssetsPickerController *picker = [[CTAssetsPickerController alloc] init];
            
            // set delegate
            picker.delegate = self;
            
            // to show selection order
            //picker.showsSelectionIndex = YES;
            
            // to present picker as a form sheet in iPad
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                picker.modalPresentationStyle = UIModalPresentationFormSheet;
            
            // present picker
            [self presentViewController:picker animated:YES completion:nil];
        });
    }];
}

/*
- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldSelectAsset:(PHAsset *)asset
{
    __block float imageSize;
    
    PHImageRequestOptions *option = [PHImageRequestOptions new];
    option.synchronous = YES;
    
    // self Asset
    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:option resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
        imageSize = imageData.length;
    }];
    
    // Add selected Asset
    for (PHAsset *asset in picker.selectedAssets) {
        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:option resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            imageSize = imageData.length + imageSize;
        }];
    }
    
    if (imageSize > MaxDimensionUpload || (picker.selectedAssets.count >= (pickerControllerMax - _numTaskUploadInProgress))) {
        
        [app messageNotification:@"_info_" description:@"_limited_dimension_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeInfo];
        
        return NO;
    }
    
    return YES;
}
*/

- (void)assetsPickerController:(CTAssetsPickerController *)picker didFinishPickingAssets:(NSMutableArray *)assets
{
    [picker dismissViewControllerAnimated:YES completion:^{
        
        [self uploadFileAsset:assets serverUrl:_localServerUrl cryptated:_isPickerCriptate session:upload_session];
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== UIDocumentInteractionControllerDelegate =====
#pragma --------------------------------------------------------------------------------------------

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller
{
    // evitiamo il rimando della eventuale photo e/o video
    if ([CCCoreData getCameraUploadActiveAccount:app.activeAccount]) {
        
        [CCCoreData setCameraUploadDatePhoto:[NSDate date]];
        [CCCoreData setCameraUploadDateVideo:[NSDate date]];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== UnZipFile =====
#pragma --------------------------------------------------------------------------------------------

- (void)unZipFile:(NSString *)fileID
{
    [_hudDeterminate visibleHudTitle:NSLocalizedString(@"_unzip_in_progress_", nil) mode:MBProgressHUDModeDeterminate color:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *fileZip = [NSString stringWithFormat:@"%@/%@", app.directoryUser, fileID];
        
        [SSZipArchive unzipFileAtPath:fileZip toDestination:[CCUtility getDirectoryLocal] overwrite:YES password:nil progressHandler:^(NSString *entry, unz_file_info zipInfo, long entryNumber, long total) {
                          
            dispatch_async(dispatch_get_main_queue(), ^{
                float progress = (float) entryNumber / (float)total;
                [_hudDeterminate progress:progress];
            });
                          
        } completionHandler:^(NSString *path, BOOL succeeded, NSError *error) {
                        
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [_hudDeterminate hideHud];
                
                if (succeeded) [app messageNotification:@"_info_" description:@"_file_unpacked_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
                else [app messageNotification:@"_error_" description:[NSString stringWithFormat:@"Error %ld", (long)error.code] visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
            });
                        
        }];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create New (OpenModel) =====
#pragma --------------------------------------------------------------------------------------------

- (void)openModel:(NSString *)tipo isNew:(BOOL)isnew
{
    UIViewController *viewController;
    NSString *fileName, *uuid, *rev, *fileID;
    BOOL modelReadOnly, isLocal;
    
    NSIndexPath * index = [self.tableView indexPathForSelectedRow];
    [self.tableView deselectRowAtIndexPath:index animated:NO];
    
    if (isnew) {
        fileName = nil;
        uuid = [CCUtility getUUID];
        rev = nil;
        fileID = nil;
        modelReadOnly = false;
        isLocal = false;
    } else {
        fileName = _metadata.fileName;
        uuid = _metadata.uuid;
        rev = _metadata.rev;
        fileID = _metadata.fileID;
        modelReadOnly = false;
        isLocal = false;
    }
    
    if ([tipo isEqualToString:@"cartadicredito"])
        viewController = [[CCCartaDiCredito alloc] initWithDelegate:self fileName:fileName uuid:uuid rev:rev fileID:fileID modelReadOnly:modelReadOnly isLocal:isLocal];
    
    if ([tipo isEqualToString:@"bancomat"])
        viewController = [[CCBancomat alloc] initWithDelegate:self fileName:fileName uuid:uuid rev:rev fileID:fileID modelReadOnly:modelReadOnly isLocal:isLocal];
    
    if ([tipo isEqualToString:@"contocorrente"])
        viewController = [[CCContoCorrente alloc] initWithDelegate:self fileName:fileName uuid:uuid rev:rev fileID:fileID modelReadOnly:modelReadOnly isLocal:isLocal];
    
    if ([tipo isEqualToString:@"accountweb"])
        viewController = [[CCAccountWeb alloc] initWithDelegate:self fileName:fileName uuid:uuid rev:rev fileID:fileID modelReadOnly:modelReadOnly isLocal:isLocal];
    
    if ([tipo isEqualToString:@"patenteguida"])
        viewController = [[CCPatenteGuida alloc] initWithDelegate:self fileName:fileName uuid:uuid rev:rev fileID:fileID modelReadOnly:modelReadOnly isLocal:isLocal];
    
    if ([tipo isEqualToString:@"cartaidentita"])
        viewController = [[CCCartaIdentita alloc] initWithDelegate:self fileName:fileName uuid:uuid rev:rev fileID:fileID modelReadOnly:modelReadOnly isLocal:isLocal];
    
    if ([tipo isEqualToString:@"passaporto"])
        viewController = [[CCPassaporto alloc] initWithDelegate:self fileName:fileName uuid:uuid rev:rev fileID:fileID modelReadOnly:modelReadOnly isLocal:isLocal];
    
    if ([tipo isEqualToString:@"note"]) {
        
        viewController = [[CCNote alloc] initWithDelegate:self fileName:fileName uuid:uuid rev:rev fileID:fileID modelReadOnly:modelReadOnly isLocal:isLocal];
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        [self presentViewController:navigationController animated:YES completion:nil];
        
    } else {
    
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

// New folder or new photo or video
- (void)returnCreate:(NSInteger)type
{
    _numTaskUploadInProgress =  [[CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (session CONTAINS 'upload') AND ((sessionTaskIdentifier >= 0) OR (sessionTaskIdentifierPlist >= 0))", app.activeAccount] context:nil] count];
    
    switch (type) {
            
        /* PLAIN */
        case returnCreateFolderPlain: {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_create_folder_",nil) message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"_cancel_",nil) otherButtonTitles:NSLocalizedString(@"_save_", nil), nil];
            [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
            alertView.tag = alertCreateFolder;
            [alertView show];
        }
            break;
        case returnCreateFotoVideoPlain: {
            
            _isPickerCriptate = false;
            
            [self openAssetsPickerController];
        }
            break;
        case returnCreateFilePlain: {
            
            _isPickerCriptate = false;
            
            [self openImportDocumentPicker];
        }
            break;
            
            
        /* ENCRYPTED */
        case returnCreateFolderEncrypted: {
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_create_folder_",nil) message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"_cancel_",nil) otherButtonTitles:NSLocalizedString(@"_save_", nil), nil];
            [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
            alertView.tag = alertCreateFolderCrypto;
            [alertView show];
        }
            break;
        case returnCreateFotoVideoEncrypted: {
            
            _isPickerCriptate = true;
            
            [self openAssetsPickerController];
        }
            break;
        case returnCreateFileEncrypted: {
            
            _isPickerCriptate = true;
            
            [self openImportDocumentPicker];
        }
            break;
    
        /* UTILITY */
        case returnNote:
            [self openModel:@"note" isNew:true];
            break;
        case returnAccountWeb:
            [self openModel:@"accountweb" isNew:true];
            break;
            
         /* BANK */
        case returnCartaDiCredito:
            [self openModel:@"cartadicredito" isNew:true];
            break;
        case returnBancomat:
            [self openModel:@"bancomat" isNew:true];
            break;
        case returnContoCorrente:
            [self openModel:@"contocorrente" isNew:true];
            break;
       
        /* DOCUMENT */
        case returnPatenteGuida:
            [self openModel:@"patenteguida" isNew:true];
            break;
        case returnCartaIdentita:
            [self openModel:@"cartaidentita" isNew:true];
            break;
        case returnPassaporto:
            [self openModel:@"passaporto" isNew:true];
            break;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Save selected File =====
#pragma --------------------------------------------------------------------------------------------

-(void)saveSelectedFilesSelector:(NSString *)path didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if (error)
        [app messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
    else
        [app messageNotification:@"_save_selected_files_" description:@"_file_saved_cameraroll_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
}

- (void)saveSelectedFiles
{
    NSLog(@"[LOG] Start download selected files ...");
    
    [_hud visibleHudTitle:@"" mode:MBProgressHUDModeIndeterminate color:nil];
    
    NSArray *metadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        for (CCMetadata *metadata in metadatas) {
            
            if (metadata.directory == NO && [metadata.type isEqualToString:metadataType_file] && ([metadata.typeFile isEqualToString:metadataTypeFile_image] || [metadata.typeFile isEqualToString:metadataTypeFile_video])) {
                
                [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selectorSave selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
            }
        }
        
        [_hud hideHud];
    });
    
    [self tableViewSelect:NO];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Change Password only Nextcloud ownCloud =====
#pragma --------------------------------------------------------------------------------------------

- (void)changePasswordAccount
{
    if (_loginVC || [app.typeCloud isEqualToString:typeCloudDropbox])
        return;
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([app.typeCloud isEqualToString:typeCloudNextcloud])
        _loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
    
    if ([app.typeCloud isEqualToString:typeCloudOwnCloud])
        _loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginOwnCloud"];
    
    [_loginVC setModifyOnlyPassword:YES];
    [_loginVC setTypeCloud:app.typeCloud];
    
    [self presentViewController:_loginVC animated:YES completion:nil];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Peek & Pop  =====
#pragma --------------------------------------------------------------------------------------------

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    CCMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (metadata.thumbnailExists && !metadata.cryptated) {
        CCCellMain *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        if (cell) {
            previewingContext.sourceRect = cell.frame;
            CCPeekPop *vc = [[UIStoryboard storyboardWithName:@"CCPeekPop" bundle:nil] instantiateViewControllerWithIdentifier:@"PeekPopImagePreview"];
            
            vc.delegate = self;
            vc.metadata = metadata;
            vc.serverUrl = _localServerUrl;
            
            return vc;
        }
    }
    
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit
{
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:previewingContext.sourceRect.origin];
    
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ======================= NetWorking ==================================
#pragma --------------------------------------------------------------------------------------------

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Request Server  ====
#pragma --------------------------------------------------------------------------------------------

- (void)getCapabilitiesOfServerSuccess:(OCCapabilities *)capabilities
{
    app.capabilities = capabilities;
}

- (void)getFeaturesSupportedByServerSuccess:(BOOL)hasCapabilitiesSupport hasForbiddenCharactersSupport:(BOOL)hasForbiddenCharactersSupport hasShareSupport:(BOOL)hasShareSupport hasShareeSupport:(BOOL)hasShareeSupport
{
    app.hasServerCapabilitiesSupport = hasCapabilitiesSupport;
    app.hasServerForbiddenCharactersSupport = hasForbiddenCharactersSupport;
    app.hasServerShareSupport = hasShareSupport;
    app.hasServerShareeSupport = hasShareeSupport;
    
    if (hasShareSupport || hasShareeSupport)
        [self requestSharedByServer];
}

- (void)getInfoServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    if (errorCode == 401)
        [self changePasswordAccount];
}

- (void)requestServerInformation
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
   
    [app.sharesID removeAllObjects];

    app.hasServerForbiddenCharactersSupport = NO;
    app.hasServerShareSupport = YES;
    
    /*** DROPBOX ***/

    if ([app.typeCloud isEqualToString:typeCloudDropbox]) {
                
        [self requestSharedByServer];
    }
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) {
        
        metadataNet.action = actionGetFeaturesSuppServer;
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
        metadataNet.action = actionGetCapabilities;
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
}

- (void)dropboxFailure
{
    [_hud hideHud];
    
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];
    
    UIAlertController * alert= [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_comm_error_dropbox_", nil) message:NSLocalizedString(@"_comm_error_dropbox_txt_", nil) preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* ok = [UIAlertAction actionWithTitle: NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [alert dismissViewControllerAnimated:YES completion:nil];
                                               }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnailSuccess:(CCMetadataNet *)metadataNet
{
    __block CCCellMain *cell;
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadataNet.fileID];
    
    if (indexPath && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadataNet.fileID]]) {
        
        cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        cell.fileImageView.image = [app.icoImagesCache objectForKey:metadataNet.fileID];
        
        if (cell.fileImageView.image == nil) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                
                UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadataNet.fileID]];
                
                [app.icoImagesCache setObject:image forKey:metadataNet.fileID];
            });
        }
     }
}

- (void)downloadThumbnailFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"[LOG] Thumbnail Error %@  %@ (error %ld)", metadataNet.fileName , message, (long)errorCode);
}

- (void)downloadThumbnail:(CCMetadata *)metadata
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionDownloadThumbnail;
    metadataNet.fileID = metadata.fileID;

    /*** DROPBOX ***/

    if ([metadata.typeCloud isEqualToString:typeCloudDropbox])
        metadataNet.fileName = metadata.fileName;
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([metadata.typeCloud isEqualToString:typeCloudOwnCloud] || [metadata.typeCloud isEqualToString:typeCloudNextcloud])
        metadataNet.fileName = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:_localServerUrl activeUrl:app.activeUrl typeCloud:app.typeCloud];
    
    metadataNet.fileNameLocal = metadata.fileID;
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.options = @"m";
    metadataNet.priority = NSOperationQueuePriorityLow;
    metadataNet.selector = selectorDownloadThumbnail;
    metadataNet.serverUrl = _localServerUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, app.activeAccount] context:nil];
    
    // File do not exists on server, remove in local
    if (errorCode == kOCErrorServerPathNotFound || errorCode == kCFURLErrorBadServerResponse) {
        [CCCoreData deleteFile:metadata serverUrl:serverUrl directoryUser:app.directoryUser typeCloud:app.typeCloud activeAccount:app.activeAccount];
    }
    
    if ([selector isEqualToString:selectorLoadViewImage] || [selector isEqualToString:selectorBrowseImages]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{

            // Updating Detail
            if (app.activeDetail)
                [app.activeDetail downloadPhotoBrowserFailure:errorCode];
            
            // Updating Photos
            if (app.activePhotosCameraUpload)
                [app.activePhotosCameraUpload downloadFileFailure:errorCode];
        });
        
    } else {
        
        if (errorCode != kCFURLErrorCancelled)
            [app messageNotification:@"_download_file_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
    }

    [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
}

- (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, app.activeAccount] context:nil];
    
    if (metadata == nil) return;

    // reload
    if ([selector isEqualToString:selectorReload]) {
        [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
    }
    
    // Synchronize
    if ([selector isEqualToString:selectorDownloadSynchronized]) {
        
        [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
    }
    
    // add Favorite
    if ([selector isEqualToString:selectorAddFavorite]) {
        [CCCoreData addFavorite:metadata.fileID activeAccount:app.activeAccount];
        [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
    }
    
    // encrypted file
    if ([selector isEqualToString:selectorEncryptFile]) {
        [self encryptedFile:metadata];
    }
    
    // decrypted file
    if ([selector isEqualToString:selectorDecryptFile]) {
        [self decryptedFile:metadata];
    }
    
    // open View File
    if ([selector isEqualToString:selectorLoadFileView] && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        
        [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
        
        if ([metadata.typeFile isEqualToString:metadataTypeFile_compress]) {
            
            [self performSelector:@selector(unZipFile:) withObject:metadata.fileID afterDelay:0.1];
            
        } else if ([metadata.typeFile isEqualToString:metadataTypeFile_unknown]) {
            
            selector = selectorOpenIn;
           
        } else {
            
            _metadataSegue = metadata;
            _metadataSegue.sessionSelector = selector;
    
            if ([self shouldPerformSegue:serverUrl])
                [self performSegueWithIdentifier:@"segueDetail" sender:self];
        }
    }
    
    // addLocal
    if ([selector isEqualToString:selectorAddLocal]) {
        
        [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] toPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryLocal], metadata.fileNamePrint]];
        
        UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        [CCGraphics saveIcoWithFileID:metadata.fileNamePrint image:image writeToFile:nil copy:YES move:NO fromPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID] toPath:[NSString stringWithFormat:@"%@/.%@.ico", [CCUtility getDirectoryLocal], metadata.fileNamePrint]];
        
        [app messageNotification:@"_add_local_" description:@"_file_saved_local_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
        
        [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
    }
    
    // Open with...
    if ([selector isEqualToString:selectorOpenIn] && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        
        [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint] error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] toPath:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint] error:nil];
        NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint]];
        
        _docController = [UIDocumentInteractionController interactionControllerWithURL:url];
        _docController.delegate = self;
        
        [_docController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES];
    }
    
    // Save to Photo Album
    if ([selector isEqualToString:selectorSave] && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        
        NSString *file = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID];
        
        if ([metadata.typeFile isEqualToString:metadataTypeFile_image]) {
            
            // evitiamo il rimando photo
            [CCCoreData setCameraUploadDatePhoto:[NSDate date]];

            UIImage *image = [UIImage imageWithContentsOfFile:file];
            
            if (image)
                UIImageWriteToSavedPhotosAlbum(image, self, @selector(saveSelectedFilesSelector: didFinishSavingWithError: contextInfo:), nil);
            else
                [app messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
        }
        
        if ([metadata.typeFile isEqualToString:metadataTypeFile_video]) {
            
            // we avoid the cross-reference video
            [CCCoreData setCameraUploadDateVideo:[NSDate date]];
            
            [[NSFileManager defaultManager] linkItemAtPath:file toPath:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint] error:nil];
            
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum([NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint])) {
                
                UISaveVideoAtPathToSavedPhotosAlbum([NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint], self, @selector(saveSelectedFilesSelector: didFinishSavingWithError: contextInfo:), nil);
            } else {
                [app messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
            }
        }
        
        [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
    }
    
    // download and view a template
    if ([selector isEqualToString:selectorLoadModelView]) {
        
        [CCCoreData downloadFilePlist:metadata activeAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud directoryUser:app.directoryUser];
        
        [self openModel:metadata.model isNew:false];
        
        [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
    }
    
    //download file plist
    if ([selector isEqualToString:selectorLoadPlist]) {
        
        [CCCoreData downloadFilePlist:metadata activeAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud directoryUser:app.directoryUser];
        
        long countSelectorLoadPlist = 0;
        
        for (NSOperation *operation in [app.netQueue operations]) {
            
            /*** NEXTCLOUD OWNCLOUD ***/
            
            if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) {
                if ([((OCnetworking *)operation).metadataNet.selector isEqualToString:selectorLoadPlist])
                    countSelectorLoadPlist++;
            }
            
#ifdef CC
            /*** DROPBOX ***/

            if ([app.typeCloud isEqualToString:typeCloudDropbox]) {
                if ([((DBnetworking *)operation).metadataNet.selector isEqualToString:selectorLoadPlist])
                    countSelectorLoadPlist++;
            }
#endif
            
        }
        
        if ((countSelectorLoadPlist == 0 || countSelectorLoadPlist % maxConcurrentOperation == 0) && [metadata.directoryID isEqualToString:_localDirectoryID]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
            });
        }
    }
    
    //selectorLoadViewImage & selectorBrowseImages
    if ([selector isEqualToString:selectorLoadViewImage] || [selector isEqualToString:selectorBrowseImages]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Detail
            if (app.activeDetail)
                [app.activeDetail downloadPhotoBrowserSuccess:metadata selector:selector];
            
            // Photos
            if (app.activePhotosCameraUpload)
                [app.activePhotosCameraUpload downloadFileSuccess:metadata];
        });

        [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:selector];
    }
    
    // if exists postselector call self with selectorPost
    if ([selectorPost length] > 0)
        [self downloadFileSuccess:fileID serverUrl:serverUrl selector:selectorPost selectorPost:nil];
}

- (void)downloadSelectedFiles
{
    NSLog(@"[LOG] Start download selected files ...");
    
    [_hud visibleHudTitle:NSLocalizedString(@"_downloading_progress_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        for (CCMetadata *metadata in selectedMetadatas) {
            if (metadata.directory == NO && [metadata.type isEqualToString:metadataType_file])
                [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selectorReload selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
        }
        
        [_hud hideHud];
    });
    
    [self tableViewSelect:NO];
}

- (void)downloadPlist:(NSString *)directoryID serverUrl:(NSString *)serverUrl
{
    NSArray *records = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND ((session == NULL) OR (session == ''))", app.activeAccount, directoryID] context:nil];
    
    for (TableMetadata *recordMetadata in records) {
            
        if ([CCUtility isCryptoPlistString:recordMetadata.fileName] && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, recordMetadata.fileName]] == NO && [recordMetadata.session length] == 0) {
        
            CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
                
            metadataNet.action = actionDownloadFile;
            metadataNet.metadata = [CCCoreData insertEntityInMetadata:recordMetadata];
            metadataNet.downloadData = NO;
            metadataNet.downloadPlist = YES;
            metadataNet.selector = selectorLoadPlist;
            metadataNet.serverUrl = serverUrl;
            metadataNet.session = download_session_foreground;
            metadataNet.taskStatus = taskStatusResume;
            
            [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Upload new Photos/Videos =====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Automatic upload
    if([selector isEqualToString:selectorUploadAutomatic] || [selector isEqualToString:selectorUploadAutomaticAll])
        [app loadTableAutomaticUploadForSelector:selector];

    // Read File test do not exists
    if (errorCode == CCErrorFileUploadNotFound) {
       
        CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", fileID, app.activeAccount] context:nil];
        
        // reUpload
        if (metadata)
            [[CCNetworking sharedNetworking] uploadFileMetadata:metadata taskStatus:taskStatusResume];
    }
    
    // Print error
    else if (errorCode != kCFURLErrorCancelled && errorCode != 403) {
        
        [app messageNotification:@"_upload_file_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
    }
    
    [self getDataSourceWithReloadTableView:[CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:app.activeAccount] fileID:nil selector:selector];
}

- (void)uploadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    // Automatic upload
    if([selector isEqualToString:selectorUploadAutomatic] || [selector isEqualToString:selectorUploadAutomaticAll])
        [app loadTableAutomaticUploadForSelector:selector];
    
    if ([selectorPost isEqualToString:selectorReadFolderForced] ) {
            
        [self readFolderWithForced:YES];
            
    } else {
    
        [self getDataSourceWithReloadTableView:[CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:app.activeAccount] fileID:nil selector:selector];
    }
}

- (void)uploadFileAsset:(NSMutableArray *)assets serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated session:(NSString *)session
{
    NSLog(@"[LOG] Asset N. %lu", (unsigned long)[assets count]);
    
    // remove title
    [self setTitleBackgroundTableView:nil];
    
    NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:serverUrl activeAccount:app.activeAccount];

    for (PHAsset *asset in assets) {
        
        NSString *fileNameUpload;
        
        // Create file name for upload
        if (cryptated) {
            CCCrypto *crypto = [[CCCrypto alloc] init];
            fileNameUpload = [NSString stringWithFormat:@"%@.plist", [crypto createFilenameEncryptor:[CCUtility createFileNameFromAsset:asset] uuid:[CCUtility getUUID]]];
        } else {
            fileNameUpload = [CCUtility createFileNameFromAsset:asset];
        }

        // Check if is in upload 
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (fileName == %@) AND (session != NULL) AND (session != '')", app.activeAccount, directoryID, fileNameUpload];
        NSArray *isRecordInSessions = [CCCoreData getTableMetadataWithPredicate:predicate context:nil];

        if ([isRecordInSessions count] > 0) {
            
            // next upload
            continue;
            
        } else {
            
            CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
            /*** DROPBOX ***/

            if ([app.typeCloud isEqualToString:typeCloudDropbox]) {
                
                metadataNet.action = actionUploadAsset;
                metadataNet.assetLocalItentifier = asset.localIdentifier;
                metadataNet.cryptated = cryptated;
                metadataNet.errorCode = 0;
                metadataNet.fileName = fileNameUpload;
                metadataNet.priority = NSOperationQueuePriorityVeryHigh;
                metadataNet.selector = selectorUploadFile;
                metadataNet.selectorPost = nil;
                metadataNet.session = session;
                metadataNet.serverUrl = serverUrl;
                metadataNet.taskStatus = taskStatusResume;
                
                if ([metadataNet.session containsString:@"wwan"])
                    [app addNetworkingOperationQueue:app.netQueueUploadWWan delegate:self metadataNet:metadataNet];
                else
                    [app addNetworkingOperationQueue:app.netQueueUpload delegate:self metadataNet:metadataNet];
            }
            
            /*** NEXTCLOUD OWNCLOUD ***/
            
            if ([app.typeCloud isEqualToString:typeCloudNextcloud] || [app.typeCloud isEqualToString:typeCloudOwnCloud]) {
            
                metadataNet.action = actionReadFile;
                metadataNet.assetLocalItentifier = asset.localIdentifier;
                metadataNet.cryptated = cryptated;
                metadataNet.fileName = fileNameUpload;
                metadataNet.priority = NSOperationQueuePriorityVeryHigh;
                metadataNet.session = session;
                metadataNet.selector = selectorReadFileUploadFile;
                metadataNet.serverUrl = serverUrl;
                
                [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
            }
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Read File ====
#pragma --------------------------------------------------------------------------------------------

- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // UploadFile
    if ([metadataNet.selector isEqualToString:selectorReadFileUploadFile]) {
        
        // File not exists
        if (errorCode == 404) {
            
            metadataNet.action = actionUploadAsset;
            metadataNet.errorCode = 0;
            metadataNet.selector = selectorUploadFile;
            metadataNet.selectorPost = nil;
            metadataNet.taskStatus = taskStatusResume;
            
            if ([metadataNet.session containsString:@"wwan"])
                [app addNetworkingOperationQueue:app.netQueueUploadWWan delegate:self metadataNet:metadataNet];
            else
                [app addNetworkingOperationQueue:app.netQueueUpload delegate:self metadataNet:metadataNet];
            
        } else {
            
            // error ho many retry befor notification and go to on next asses
            if (metadataNet.errorRetry < 3) {
                
                // Retry read file
                [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
                
            } else {
                
                // STOP check file, view message error
                [app messageNotification:@"_upload_file_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];                
            }
        }
    }
}

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(CCMetadata *)metadata
{
    // ReadFile Folder for change rev
    if ([metadataNet.selector isEqualToString:selectorReadFileFolder]) {
        
        NSString *rev = [CCCoreData getDirectoryRevFromServerUrl:metadataNet.serverUrl activeAccount:app.activeAccount];
        
        if (![metadata.rev isEqualToString:rev]) {
            
            NSLog(@"Change etag, force reload folder %@", metadataNet.serverUrl);
            
            [CCCoreData setDirectoryRev:metadata.rev serverUrl:metadataNet.serverUrl activeAccount:app.activeAccount];
            [CCCoreData clearDateReadDirectory:metadataNet.serverUrl activeAccount:app.activeAccount];
            
            CCMain *viewController = [app.listMainVC objectForKey:metadataNet.serverUrl];
            if (viewController)
                [viewController clearDateReadDataSource:nil];
        }
    }
    
    // UploadFile
    if ([metadataNet.selector isEqualToString:selectorReadFileUploadFile]) {
        
        metadataNet.action = actionUploadAsset;
        metadataNet.errorCode = 403;                // File exists 403 Forbidden
        metadataNet.selector = selectorUploadFile;
        metadataNet.selectorPost = nil;
        metadataNet.taskStatus = taskStatusResume;
        
        if ([metadataNet.session containsString:@"wwan"])
            [app addNetworkingOperationQueue:app.netQueueUploadWWan delegate:self metadataNet:metadataNet];
        else
            [app addNetworkingOperationQueue:app.netQueueUpload delegate:self metadataNet:metadataNet];
    }
}

- (void)readFileSelfFolderRev
{
    // test
    if ([app.activeAccount length] == 0 || [_localDirectoryID length] == 0)
        return;

    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];

    metadataNet.action = actionReadFile;
    metadataNet.selector = selectorReadFileFolder;
    metadataNet.serverUrl = [CCCoreData getServerUrlFromDirectoryID:_localDirectoryID activeAccount:app.activeAccount];

    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Read Folder ====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // verify active user
    TableAccount *record = [CCCoreData getActiveAccount];
    
    [_hud hideHud];

    [_ccRefreshControl endRefreshing];
        
    [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
    
    if (message && [record.account isEqualToString:metadataNet.account])
        [app messageNotification:@"_error_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
    
    [self getDataSourceWithReloadTableView:metadataNet.directoryID fileID:nil selector:metadataNet.selector];
    
    if (errorCode == 401)
        [self changePasswordAccount];
}

- (void)readFolderSuccess:(CCMetadataNet *)metadataNet permissions:(NSString *)permissions rev:(NSString *)rev metadatas:(NSArray *)metadatas
{
    // verify active user
    TableAccount *record = [CCCoreData getActiveAccount];

    if (![record.account isEqualToString:metadataNet.account])
        return;
    
    // save father e update permission
    _fatherPermission = permissions;
    
    [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND ((session == NULL) OR (session == ''))", app.activeAccount, metadataNet.directoryID]];
    
    NSArray *recordsInSessions = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", app.activeAccount, metadataNet.directoryID] context:nil];

    [CCCoreData setDateReadDirectoryID:metadataNet.directoryID activeAccount:app.activeAccount];
    
    for (CCMetadata *metadata in metadatas) {
        
        // type of file
        NSInteger typeFilename = [CCUtility getTypeFileName:metadata.fileName];
        
        // if crypto do not insert
        if (typeFilename == metadataTypeFilenameCrypto) continue;
        
        // verify if the record encrypted has plist + crypto
        if (typeFilename == metadataTypeFilenamePlist && metadata.directory == NO) {
            
            BOOL isCryptoComplete = NO;
            NSString *fileNameCrypto = [CCUtility trasformedFileNamePlistInCrypto:metadata.fileName];
            
            for (CCMetadata *completeMetadata in metadatas) {
                    
                if (completeMetadata.cryptated == NO) continue;
                else  if ([completeMetadata.fileName isEqualToString:fileNameCrypto]) {
                    isCryptoComplete = YES;
                    break;
                }
            }
            if (isCryptoComplete == NO) continue;
        }
        
        // verify if the record is in download/upload progress
        if (metadata.directory == NO && [recordsInSessions count] > 0) {
            
            CCMetadata *metadataDB = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND (fileName == %@)", app.activeAccount, metadataNet.directoryID, metadata.fileName] context:nil];
            
            // Upload
            if (metadataDB.session && [metadataDB.session rangeOfString:@"upload"].location != NSNotFound) {
                
                NSString *sessionID = metadataDB.sessionID;
                
                // rename SessionID -> fileID
                [CCUtility moveFileAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, sessionID]  toPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]];
                
                metadataDB.session = @"";
                metadataDB.date = metadata.date;
                metadataDB.fileID = metadata.fileID;
                metadataDB.rev = metadata.fileID;
                metadataDB.sessionError = @"";
                metadataDB.sessionID = @"";
                metadataDB.sessionTaskIdentifier = taskIdentifierDone;
                metadataDB.sessionTaskIdentifierPlist = taskIdentifierDone;
                
                [CCCoreData updateMetadata:metadataDB predicate:[NSPredicate predicateWithFormat:@"(sessionID == %@) AND (account == %@)", sessionID, app.activeAccount] activeAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud context:nil];
                
                [CCCoreData addLocalFile:metadataDB activeAccount:app.activeAccount];
                
                [CCGraphics createNewImageFrom:metadata.fileID directoryUser:app.directoryUser fileNameTo:metadata.fileID fileNamePrint:metadata.fileNamePrint size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
                
                continue;
            }
            
            // download in progress
            if (metadataDB.session && [metadataDB.session rangeOfString:@"download"].location != NSNotFound) continue;
        }

        // test rev subdirectory
        /*
        if (metadata.directory) {
            
            NSString *serverUrlTestRev = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:metadata.fileName];
            NSString *revPrev = [CCCoreData getDirectoryRevFromServerUrl:serverUrlTestRev activeAccount:app.activeAccount];
            
            if (![metadata.rev isEqualToString:revPrev]) {
                
                NSLog(@"Change etag, force reload folder");
                
                [CCCoreData setDirectoryRev:metadata.rev serverUrl:serverUrlTestRev activeAccount:app.activeAccount];
                [CCCoreData clearDateReadDirectory:serverUrlTestRev activeAccount:app.activeAccount];
                
                CCMain *viewController = [app.listMainVC objectForKey:serverUrlTestRev];
                if (viewController)
                    [viewController clearDateReadDataSource:nil];
            }
        }
        */
        
        // end test, insert in CoreData
        [CCCoreData addMetadata:metadata activeAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud context:nil];
    }
    
    // read plist
    [self downloadPlist:metadataNet.directoryID serverUrl:metadataNet.serverUrl];
    
    // Synchronization directory
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        [[CCSynchronization sharedSynchronization] verifyChangeMedatas:metadatas serverUrl:metadataNet.serverUrl directoryID:metadataNet.directoryID account:app.activeAccount synchronization:NO];
    });

    // this is the same directory
    if ([metadataNet.serverUrl isEqualToString:_localServerUrl]) {
        
        // reload
        [self getDataSourceWithReloadTableView:metadataNet.directoryID fileID:nil selector:metadataNet.selector];
    
        // stoprefresh
        [_ccRefreshControl endRefreshing];
    
        // Enable change user
        [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
                
        [_hud hideHud];
    }
}

- (void)readFolderWithForced:(BOOL)forced
{
    [self setTitleBackgroundTableView:nil];
 
    // init control
    if (!_localServerUrl || !app.activeAccount)
        return;
    
    if (([CCCoreData isDirectoryOutOfDate:dayForceReadFolder directoryID:_localDirectoryID activeAccount:app.activeAccount] || forced) && _localDirectoryID && app.activeAccount) {
        
        if (_ccRefreshControl.isRefreshing == NO)
            [_hud visibleIndeterminateHud];
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionReadFolder;
        metadataNet.date = [NSDate date];
        metadataNet.directoryID = _localDirectoryID;
        metadataNet.priority = NSOperationQueuePriorityVeryHigh;
        metadataNet.selector = selectorReadFolder;
        metadataNet.serverUrl = [CCCoreData getServerUrlFromDirectoryID:_localDirectoryID activeAccount:app.activeAccount];

        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
    } else {
        
        if ([_sectionDataSource.allRecordsDataSource count] == 0) [self setTitleBackgroundTableView:NSLocalizedString(@"_no_file_pull_down_",nil)];
        else [self setTitleBackgroundTableView:nil];
    }
}


#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete File or Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];
    
    if (errorCode == 404)
        [self deleteFileOrFolderSuccess:metadataNet];
    
    if (message)
        [app messageNotification:@"_delete_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];

    // is detailViewController active ?
    if (_detailViewController) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_detailViewController deleteFileFailure:errorCode];
        });
    }
    
    [_selectedMetadatas removeAllObjects];
    [_queueSelector removeAllObjects];
}

- (void)deleteFileOrFolderSuccess:(CCMetadataNet *)metadataNet
{
    [_queueSelector removeObject:metadataNet.selector];
    
    if ([_queueSelector count] == 0) {
        
        [_hud hideHud];
        
        CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadataNet.fileID, app.activeAccount] context:nil];
        
        if (metadata) {
            
            [CCCoreData deleteFile:metadata serverUrl:metadataNet.serverUrl directoryUser:app.directoryUser typeCloud:app.typeCloud activeAccount:app.activeAccount];
            
            // Carico la Folder o il Datasource
            if ([metadataNet.selectorPost isEqualToString:selectorReadFolderForced]) {
                [self readFolderWithForced:YES];
            } else {
                [self getDataSourceWithReloadTableView:metadata.directoryID fileID:metadata.fileID selector:metadataNet.selector];
            }
        }

        // if detailViewController
        if (_detailViewController) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_detailViewController deleteFileSuccess:metadata metadataNetVar:metadataNet];
            });
        }

        // next
        if ([_selectedMetadatas count] > 0) {
            
            [_selectedMetadatas removeObjectAtIndex:0];
            
            if ([_selectedMetadatas count] > 0)
                [self deleteFileOrFolder:[_selectedMetadatas objectAtIndex:0] numFile:[_selectedMetadatas count] ofFile:_numSelectedMetadatas];
        }
    }
}

- (void)deleteFileOrFolder:(CCMetadata *)metadata numFile:(NSInteger)numFile ofFile:(NSInteger)ofFile
{
    if (metadata.cryptated == YES) {
        
        // Cryptated
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionDeleteFileDirectory;
        metadataNet.fileID = metadata.fileID;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.serverUrl = _localServerUrl;

        // data crypto
        metadataNet.fileName = metadata.fileNameData;
        metadataNet.selector = selectorDeleteCrypto;
            
        [_queueSelector addObject:metadataNet.selector];
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
        // plist
        metadataNet.fileName = metadata.fileName;
        metadataNet.selector = selectorDeletePlist;
            
        [_queueSelector addObject:metadataNet.selector];
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
            
    } else {
            
        // Plain
    
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionDeleteFileDirectory;
        metadataNet.fileID = metadata.fileID;
        metadataNet.fileName = metadata.fileName;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.selector = selectorDelete;
        metadataNet.serverUrl = _localServerUrl;
        
        [_queueSelector addObject:metadataNet.selector];
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
        
    [_hud visibleHudTitle:[NSString stringWithFormat:NSLocalizedString(@"_delete_file_n_", nil), ofFile - numFile + 1, ofFile] mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)deleteSelectionFile
{
    [_selectedMetadatas removeAllObjects];
    [_queueSelector removeAllObjects];
    
    _selectedMetadatas = [[NSMutableArray alloc] initWithArray: [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]]];
    _numSelectedMetadatas = [_selectedMetadatas count];
    
    if ([_selectedMetadatas count] > 0)
        [self deleteFileOrFolder:[_selectedMetadatas objectAtIndex:0] numFile:[_selectedMetadatas count] ofFile:_numSelectedMetadatas];
    
    [self tableViewSelect:NO];
}

- (void)deleteFile
{
    [_selectedMetadatas removeAllObjects];
    [_queueSelector removeAllObjects];
    _numSelectedMetadatas = 1;
    
    [_selectedMetadatas addObject:_metadata];
    
    if ([_selectedMetadatas count] > 0)
        [self deleteFileOrFolder:[_selectedMetadatas objectAtIndex:0] numFile:[_selectedMetadatas count] ofFile:_numSelectedMetadatas];
    
    [self tableViewSelect:NO];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Rename =====
#pragma --------------------------------------------------------------------------------------------

- (void)renameSuccess:(CCMetadataNet *)metadataNet revTo:(NSString *)revTo
{
    CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadataNet.fileID, app.activeAccount] context:nil];
    
    /*** DROPBOX ***/

    if ([app.typeCloud isEqualToString:typeCloudDropbox] && [metadataNet.selector isEqualToString:selectorMoveCrypto] == NO) {
        
        // Drop Box cambia rev, quindi cambio etav e rev da metadata.rev e metadata.fileID ----> revTo
        [CCCoreData changeRevFileIDDB:metadata.rev revTo:revTo activeAccount:app.activeAccount];
            
        // change file
        [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/%@",app.directoryUser,metadata.fileID] toPath:[NSString stringWithFormat:@"%@/%@",app.directoryUser,revTo] error:nil];
        
        UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico",app.directoryUser,metadata.fileID]];
        [CCGraphics saveIcoWithFileID:revTo image:image writeToFile:nil copy:NO move:YES fromPath:[NSString stringWithFormat:@"%@/%@.ico",app.directoryUser,metadata.fileID] toPath:[NSString stringWithFormat:@"%@/%@.ico",app.directoryUser,revTo]];
        
        metadata.fileID = revTo;
        metadata.rev = revTo;
    }

    if (metadata.directory == YES)
        [CCCoreData renameDirectory:[CCUtility stringAppendServerUrl:metadataNet.serverUrl addServerUrl:metadataNet.fileName] serverUrlTo:[CCUtility stringAppendServerUrl:metadataNet.serverUrl addServerUrl:metadataNet.fileNameTo] activeAccount:app.activeAccount];
    else
        [CCCoreData renameLocalFileWithFileID:metadata.fileID fileNameTo:metadataNet.fileNameTo fileNamePrintTo:metadataNet.fileNameTo activeAccount:app.activeAccount];
    
    if ([metadataNet.selectorPost isEqualToString:selectorReadFolderForced])
        [self readFolderWithForced:YES];
}

- (void)renameFile:(CCMetadata *)metadata fileName:(NSString *)fileName
{
    NSString *fileNameTo, *newTitleTo;
    CCCrypto *crypto = [[CCCrypto alloc] init];
    
    fileNameTo = [CCUtility removeForbiddenCharacters:fileName];
    if (![fileNameTo length]) return;
    
    if ([metadata.fileNamePrint isEqualToString:fileNameTo]) return;
    
    // Plain
    if (metadata.cryptated == NO) {
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionMoveFileOrFolder;
        metadataNet.fileID = metadata.fileID;
        metadataNet.fileName = metadata.fileName;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.fileNameTo = fileNameTo;
        metadataNet.selector = selectorRename;
        metadataNet.selectorPost = selectorReadFolderForced;
        metadataNet.serverUrl = _localServerUrl;
        metadataNet.serverUrlTo = _localServerUrl;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
    } else {
        
        // Change only  the contenent of plist, then upload it
        newTitleTo = [AESCrypt encrypt:fileNameTo password:[crypto getKeyPasscode:metadata.uuid]];
        
        if ([crypto updateTitleFilePlist:metadata.fileName title:newTitleTo directoryUser:app.directoryUser] == NO) {
            
            NSLog(@"[LOG] Rename cryptated error %@", fileName);
            
            [app messageNotification:@"_rename_" description:@"_file_not_found_reload_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];

            return;
        }
        
        if (metadata.directory == NO) {
            // cripto il file fileID in temp
            NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]];
            if (data) data = [RNEncryptor encryptData:data withSettings:kRNCryptorAES256Settings password:[crypto getKeyPasscode:metadata.uuid] error:nil];
            if (data) [data writeToFile:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNameData] atomically:YES];
        }
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionUploadOnlyPlist;
        metadataNet.fileName = metadata.fileName;
        metadataNet.selectorPost = selectorReadFolderForced;
        metadataNet.serverUrl = _localServerUrl;
        metadataNet.session = upload_session_foreground;
        metadataNet.taskStatus = taskStatusResume;
        
        if ([CCCoreData isFavorite:metadata.fileID activeAccount:app.activeAccount]) metadataNet.selectorPost = selectorAddFavorite;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
        // delete file in filesystem
        [CCCoreData deleteFile:metadata serverUrl:_localServerUrl directoryUser:app.directoryUser typeCloud:app.typeCloud activeAccount:app.activeAccount];
    }
}

- (void)renameNote:(CCMetadata *)metadata fileName:(NSString *)fileName
{
    CCTemplates *templates = [[CCTemplates alloc] init];
    CCCrypto *crypto = [[CCCrypto alloc] init];
    
    NSMutableDictionary *field = [crypto getDictionaryEncrypted:metadata.fileName uuid:metadata.uuid isLocal:NO directoryUser:app.directoryUser];
    NSString *fileNameModel = [templates salvaNote:[field objectForKey:@"note"] titolo:fileName fileName:metadata.fileName uuid:metadata.uuid];
    
    if (fileNameModel) {
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionUploadTemplate;
        metadataNet.fileName = [CCUtility trasformedFileNamePlistInCrypto:fileNameModel];
        metadataNet.fileNamePrint = fileName;
        metadataNet.rev = metadata.rev;
        metadataNet.serverUrl = _localServerUrl;
        metadataNet.session = upload_session_foreground;
        metadataNet.taskStatus = taskStatusResume;
        
        if ([CCCoreData isFavorite:metadata.fileID activeAccount:app.activeAccount]) metadataNet.selectorPost = selectorAddFavorite;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Move =====
#pragma --------------------------------------------------------------------------------------------

- (void)moveFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];
    
    if (message)
        [app messageNotification:@"_move_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
    
    [_selectedMetadatas removeAllObjects];
    [_queueSelector removeAllObjects];
}

- (void)moveSuccess:(CCMetadataNet *)metadataNet revTo:(NSString *)revTo
{
    [_queueSelector removeObject:metadataNet.selector];
    
    if ([_queueSelector count] == 0) {
    
        [_hud hideHud];
        
        NSString *fileName = [CCUtility trasformedFileNameCryptoInPlist:metadataNet.fileName];
        NSString *directoryID = metadataNet.directoryID;
        NSString *directoryIDTo = metadataNet.directoryIDTo;

        /*** DROPBOX ***/

        if ([app.typeCloud isEqualToString:typeCloudDropbox]) {
        
            // Drop Box change rev
            [CCCoreData changeRevFileIDDB:metadataNet.rev revTo:revTo activeAccount:app.activeAccount];
            
            // fileID -> rev ;
            [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/%@",app.directoryUser,metadataNet.fileID] toPath:[NSString stringWithFormat:@"%@/%@",app.directoryUser,revTo] error:nil];
            [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/%@.ico",app.directoryUser,metadataNet.fileID] toPath:[NSString stringWithFormat:@"%@/%@.ico",app.directoryUser,revTo] error:nil];
        }
    
        // FILE -> Metadata
        if (metadataNet.directory == NO) {
            
            // se esiste l' directoryIDTo destinazione allora cambiamo il file sul nuovo directoryID altrimenti cancelliamo il file
            if (directoryIDTo)
                [CCCoreData moveMetadata:fileName directoryID:directoryID directoryIDTo:directoryIDTo activeAccount:app.activeAccount];
            else
                [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(directoryID == %@)AND (account == %@)", directoryID, app.activeAccount]];
        }
    
        // DIRECTORY ->  Directory - CCMetadata
        if (metadataNet.directory == YES) {
        
            // cancelliamo tutte le directory e subdirectory in Directory prelevando i fileID
            NSArray *directoryIDs = [CCCoreData deleteDirectoryAndSubDirectory:[CCUtility stringAppendServerUrl:metadataNet.serverUrl addServerUrl:fileName] activeAccount:app.activeAccount];
        
            // cancelliamo in metadata tutti i file degli fileID prelevati da directory
            for(NSString *directoryIDDelete in directoryIDs) {
                [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(directoryID == %@)AND (account == %@)",directoryIDDelete, app.activeAccount]];
            }
        
            // rinominiamo ora la directory in CCMetadata
            if (directoryIDTo)
                [CCCoreData moveMetadata:fileName directoryID:directoryID directoryIDTo:directoryIDTo activeAccount:app.activeAccount];
        }
    
        // reload Datasource
        if ([metadataNet.selectorPost isEqualToString:selectorReadFolderForced])
            [self readFolderWithForced:YES];
        else
            [self getDataSourceWithReloadTableView];

        // Next file
        [_selectedMetadatas removeObjectAtIndex:0];
        [self moveFileOrFolder:metadataNet.serverUrlTo];
    }
}

- (void)moveFileOrFolder:(NSString *)serverUrlTo
{
    if ([_selectedMetadatas count] > 0) {
        
         CCMetadata *metadata = [_selectedMetadatas objectAtIndex:0];
        
        // Plain
        if (metadata.cryptated == NO) {
            
            CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
            metadataNet.action = actionMoveFileOrFolder;
            metadataNet.directory = metadata.directory;
            metadataNet.fileID = metadata.fileID;
            metadataNet.directoryID = _localDirectoryID;
            metadataNet.directoryIDTo = [CCCoreData getDirectoryIDFromServerUrl:serverUrlTo activeAccount:app.activeAccount];
            metadataNet.fileName = metadata.fileName;
            metadataNet.fileNamePrint = metadataNet.fileNamePrint;
            metadataNet.fileNameTo = metadata.fileName;
            metadataNet.rev = metadata.rev;
            metadataNet.selector = selectorMove;
            metadataNet.serverUrl = _localServerUrl;
            metadataNet.serverUrlTo = serverUrlTo;
            
            [_queueSelector addObject:metadataNet.selector];
            
            [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        }
        
        // cyptated
        if (metadata.cryptated == YES) {
            
            CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
            metadataNet.action = actionMoveFileOrFolder;
            metadataNet.directory = metadata.directory;
            metadataNet.fileID = metadata.fileID;
            metadataNet.directoryID = _localDirectoryID;
            metadataNet.directoryIDTo = [CCCoreData getDirectoryIDFromServerUrl:serverUrlTo activeAccount:app.activeAccount];
            metadataNet.fileNamePrint = metadata.fileNamePrint;
            metadataNet.rev = metadata.rev;
            metadataNet.serverUrl = _localServerUrl;
            metadataNet.serverUrlTo = serverUrlTo;
            
            // data
            metadataNet.fileName = metadata.fileNameData;
            metadataNet.fileNameTo = metadata.fileNameData;
            metadataNet.selector = selectorMoveCrypto;
            
            [_queueSelector addObject:metadataNet.selector];
            [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
            
            // plist
            metadataNet.fileName = metadata.fileName;
            metadataNet.fileNameTo = metadata.fileName;
            metadataNet.selector = selectorMovePlist;
            
            [_queueSelector addObject:metadataNet.selector];
            [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        }
        
        [_hud visibleHudTitle:[NSString stringWithFormat:NSLocalizedString(@"_move_file_n_", nil), _numSelectedMetadatas - [_selectedMetadatas count] + 1, _numSelectedMetadatas] mode:MBProgressHUDModeIndeterminate color:nil];
    }
}

- (void)move:(NSString *)serverUrlTo title:(NSString *)title selectedMetadatas:(NSArray *)selectedMetadatas
{
    // Test
    if ([_localServerUrl isEqualToString:serverUrlTo]) {
        
        [self tableViewSelect:NO];
        return;
    }
    
    [_selectedMetadatas removeAllObjects];
    [_queueSelector removeAllObjects];
    
    _selectedMetadatas = [[NSMutableArray alloc] initWithArray:selectedMetadatas];
    _numSelectedMetadatas = [_selectedMetadatas count];
    
    [self moveFileOrFolder:serverUrlTo];
    [self tableViewSelect:NO];
}

- (void)moveOpenWindow:(NSArray *)indexPaths
{
    UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMove"];
    
    CCMove *viewController = (CCMove *)navigationController.topViewController;

    viewController.delegate = self;
    viewController.move.title = NSLocalizedString(@"_move_", nil);
    viewController.selectedMetadatas = [self getMetadatasFromSelectedRows:indexPaths];
    viewController.tintColor = COLOR_BRAND;
    viewController.barTintColor = COLOR_BAR;
    viewController.tintColorTitle = COLOR_GRAY;
    viewController.networkingOperationQueue = app.netQueue;
    
    [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)createFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];
    
    if (message)
        [app messageNotification:@"_create_folder_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
}

- (void)createFolderSuccess:(CCMetadataNet *)metadataNet
{
    [_hud hideHud];
    
    [CCCoreData addDirectory:[NSString stringWithFormat:@"%@/%@", metadataNet.serverUrl, metadataNet.fileName] date:[NSDate date] permissions:nil activeAccount:app.activeAccount];
    
    // Load Folder or the Datasource
    if ([metadataNet.selectorPost isEqualToString:selectorReadFolderForced]) {
        [self readFolderWithForced:YES];
    } else {
        [self getDataSourceWithReloadTableView:_localDirectoryID fileID:metadataNet.fileID selector:metadataNet.selector];
    }
}

- (void)createFolder:(NSString *)fileNameFolder folderCameraUpload:(BOOL)folderCameraUpload
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    fileNameFolder = [CCUtility removeForbiddenCharacters:fileNameFolder];
    if (![fileNameFolder length]) return;
    
    if (folderCameraUpload) metadataNet.serverUrl = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
    else  metadataNet.serverUrl = _localServerUrl;
    
    metadataNet.action = actionCreateFolder;
    if (folderCameraUpload)
        metadataNet.options = @"folderCameraUpload";
    metadataNet.fileName = fileNameFolder;
    metadataNet.selector = selectorCreateFolder;
    metadataNet.selectorPost = selectorReadFolderForced;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    if (!folderCameraUpload)
        [_hud visibleHudTitle:NSLocalizedString(@"_create_folder_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)createFolderEncrypted:(NSString *)fileNameFolder
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    CCCrypto *crypto = [[CCCrypto alloc] init];
    NSString *fileNamePlist;
    
    fileNameFolder = [CCUtility removeForbiddenCharacters:fileNameFolder];
    if (![fileNameFolder length]) return;
    
    NSString *title = [AESCrypt encrypt:fileNameFolder password:[crypto getKeyPasscode:[CCUtility getUUID]]];

    fileNamePlist =  [crypto createFilenameEncryptor:fileNameFolder uuid:[CCUtility getUUID]];
    
    [crypto createFilePlist:[NSTemporaryDirectory() stringByAppendingString:fileNamePlist] title:title len:0 directory:true uuid:[CCUtility getUUID] nameCurrentDevice:[CCUtility getNameCurrentDevice] icon:@""];
    
    // Create folder
    metadataNet.action = actionCreateFolder;
    metadataNet.fileName = fileNamePlist;
    metadataNet.priority = NSOperationQueuePriorityVeryHigh;
    metadataNet.selector = selectorCreateFolder;
    metadataNet.serverUrl = _localServerUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    // upload plist file
    metadataNet.action = actionUploadOnlyPlist;
    metadataNet.fileName = [fileNamePlist stringByAppendingString:@".plist"];
    metadataNet.priority = NSOperationQueuePriorityVeryLow;
    metadataNet.selectorPost = selectorReadFolderForced;
    metadataNet.serverUrl = _localServerUrl;
    metadataNet.session = upload_session_foreground;
    metadataNet.taskStatus = taskStatusResume;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleHudTitle:NSLocalizedString(@"_create_folder_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)createFolderCameraUpload
{
    [self createFolder:[CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount] folderCameraUpload:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Encrypted / Decrypted Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)encyptedDecryptedFolder
{
    if (_metadata.cryptated) {
        
        // DECRYPTED
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        //-------------------------- RENAME -------------------------------------------//
        
        metadataNet.action = actionMoveFileOrFolder;
        metadataNet.fileID = _metadata.fileID;
        metadataNet.fileName = _metadata.fileNameData;
        metadataNet.fileNameTo = _metadata.fileNamePrint;
        metadataNet.fileNamePrint = _metadata.fileNamePrint;
        metadataNet.priority = NSOperationQueuePriorityVeryHigh;
        metadataNet.selector = selectorRename;
        metadataNet.serverUrl = _localServerUrl;
        metadataNet.serverUrlTo = _localServerUrl;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
        //-------------------------- DELETE -------------------------------------------//
        
        metadataNet.action = actionDeleteFileDirectory;
        metadataNet.fileID = _metadata.fileID;
        metadataNet.fileName = _metadata.fileName;
        metadataNet.fileNamePrint = _metadata.fileNamePrint;
        metadataNet.priority = NSOperationQueuePriorityVeryLow;
        metadataNet.selector = selectorDeletePlist;
        metadataNet.selectorPost = selectorReadFolderForced;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
    } else {
                
        // ENCRYPTED
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        CCCrypto *crypto = [[CCCrypto alloc] init];
        
        // Create File Plist
        NSString *fileNameCrypto = [crypto createFileDirectoryPlist:_metadata];
        
        //-------------------------- RENAME -------------------------------------------//
        
        metadataNet.action = actionMoveFileOrFolder;
        metadataNet.fileID = _metadata.fileID;
        metadataNet.fileName = _metadata.fileName;
        metadataNet.fileNamePrint = _metadata.fileNamePrint;
        metadataNet.fileNameTo = fileNameCrypto;
        metadataNet.priority = NSOperationQueuePriorityVeryHigh;
        metadataNet.selector = selectorRename;
        metadataNet.serverUrl = _localServerUrl;
        metadataNet.serverUrlTo = _localServerUrl;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
        //-------------------------- UPLOAD -------------------------------------------//
        
        metadataNet.action = actionUploadOnlyPlist;
        metadataNet.fileName = [fileNameCrypto stringByAppendingString:@".plist"];
        metadataNet.priority = NSOperationQueuePriorityVeryLow;
        metadataNet.selectorPost = selectorReadFolderForced;
        metadataNet.serverUrl = _localServerUrl;
        metadataNet.session = upload_session_foreground;
        metadataNet.taskStatus = taskStatusResume;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Encrypted/Decrypted File =====
#pragma --------------------------------------------------------------------------------------------

- (void)encryptedSelectedFiles
{
    NSMutableArray *metadatas = [[NSMutableArray alloc] init];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    for (CCMetadata *metadata in selectedMetadatas) {
        if (metadata.cryptated == NO && metadata.directory == NO)
            [metadatas addObject:metadata];
    }
    
    if ([metadatas count] > 0) {
        
        NSLog(@"[LOG] Start encrypted selected files ...");
    
        for (CCMetadata* metadata in metadatas)
            [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selectorEncryptFile selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
    }
    
    [self tableViewSelect:NO];
}

- (void)decryptedSelectedFiles
{
    NSMutableArray *metadatas = [[NSMutableArray alloc] init];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    for (CCMetadata *metadata in selectedMetadatas) {
        if (metadata.cryptated == YES && metadata.directory == NO && [metadata.model length] == 0)
            [metadatas addObject:metadata];
    }
    
    if ([metadatas count] > 0) {
        
        NSLog(@"[LOG] Start decrypted selected files ...");
        
        for (CCMetadata* metadata in metadatas)
            [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selectorDecryptFile selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
    }
    
    [self tableViewSelect:NO];
}

- (void)cmdEncryptedDecryptedFile
{
    NSString *selector;
    
    if (_metadata.cryptated == YES) selector = selectorDecryptFile;
    if (_metadata.cryptated == NO) selector = selectorEncryptFile;
    
    [[CCNetworking sharedNetworking] downloadFile:_metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selector selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
}

- (void)encryptedFile:(CCMetadata *)metadata
{
    NSString *fileNameFrom = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID];
    NSString *fileNameTo = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileNamePrint];
    [[NSFileManager defaultManager] copyItemAtPath:fileNameFrom toPath:fileNameTo error:nil];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileNameTo]) {
        
        NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
                
        dispatch_async(dispatch_get_main_queue(), ^{
            [[CCNetworking sharedNetworking] uploadFile:metadata.fileName serverUrl:serverUrl cryptated:YES onlyPlist:NO session:upload_session taskStatus:taskStatusResume selector:nil selectorPost:nil parentRev:nil errorCode:0 delegate:nil];
            [self performSelector:@selector(getDataSourceWithReloadTableView) withObject:nil afterDelay:0.1];
        });
        
    } else {
            
        [app messageNotification:@"_encrypted_selected_files_" description:@"_file_not_present_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
    }
}

- (void)decryptedFile:(CCMetadata *)metadata
{
    NSString *fileNameFrom = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID];
    NSString *fileNameTo = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileNamePrint];
        
    [[NSFileManager defaultManager] copyItemAtPath:fileNameFrom toPath:fileNameTo error:nil];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileNameTo]) {
        
        NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:metadata.directoryID activeAccount:app.activeAccount];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[CCNetworking sharedNetworking] uploadFile:metadata.fileNamePrint serverUrl:serverUrl cryptated:NO onlyPlist:NO session:upload_session taskStatus:taskStatusResume selector:nil selectorPost:nil parentRev:nil errorCode:0 delegate:nil];
            [self performSelector:@selector(getDataSourceWithReloadTableView) withObject:nil afterDelay:0.1];
        });
        
    } else {
            
        [app messageNotification:@"_decrypted_selected_files_" description:@"_file_not_present_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)progressTask:(NSString *)fileID serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated progress:(float)progress;
{
    // Check
    if (!fileID)
        return;
    
    [app.listProgressMetadata setObject:[NSNumber numberWithFloat:progress] forKey:fileID];

    if (![serverUrl isEqualToString:_localServerUrl])
        return;

    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:fileID];
    
    if (indexPath) {
        
        CCControlCenterCell *cell = (CCControlCenterCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        
        if (cryptated) cell.progressView.progressTintColor = COLOR_ENCRYPTED;
        else cell.progressView.progressTintColor = COLOR_CLEAR;
        
        cell.progressView.hidden = NO;
        [cell.progressView setProgress:progress];
    }
}

- (void)reloadTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        CCMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
        
        if (metadata)
            [self reloadTaskButton:metadata];
    }
}

- (void)reloadTaskButton:(CCMetadata *)metadata
{
    NSURLSession *session = [[CCNetworking sharedNetworking] getSessionfromSessionDescription:metadata.session];
    __block NSURLSessionTask *findTask;
    
    // DOWNLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"download"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionUploadTask *task in downloadTasks)
                if (task.taskIdentifier == metadata.sessionTaskIdentifier || task.taskIdentifier == metadata.sessionTaskIdentifierPlist) {
                    findTask = task;
                    [app.listChangeTask setObject:@"reloadDownload" forKey:metadata.fileID];
                    [task cancel];
                }
            
            if (!findTask) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [app.listChangeTask setObject:@"reloadDownload" forKey:metadata.fileID];
                    NSArray *object = [[NSArray alloc] initWithObjects:session, metadata, findTask, nil];
                    [[NSNotificationCenter defaultCenter] postNotificationName:networkingSessionNotification object:object];
                });
            }
        }];
    }

    // UPLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"upload"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionUploadTask *task in uploadTasks)
                if (task.taskIdentifier == metadata.sessionTaskIdentifier || task.taskIdentifier == metadata.sessionTaskIdentifierPlist) {
                    findTask = task;
                    [app.listChangeTask setObject:@"reloadUpload" forKey:metadata.fileID];
                    [task cancel];
                }
            
            if (!findTask) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [app.listChangeTask setObject:@"reloadUpload" forKey:metadata.fileID];
                    NSArray *object = [[NSArray alloc] initWithObjects:session, metadata, findTask, nil];
                    [[NSNotificationCenter defaultCenter] postNotificationName:networkingSessionNotification object:object];
                });
            }
        }];
    }
}

- (void)cancelTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        CCMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
        
        if (metadata)
            [self cancelTaskButton:metadata reloadTable:YES];
    }
}

- (void)cancelTaskButton:(CCMetadata *)metadata reloadTable:(BOOL)reloadTable
{
    NSURLSession *session = [[CCNetworking sharedNetworking] getSessionfromSessionDescription:metadata.session];
    __block NSURLSessionTask *findTask;

    // DOWNLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"download"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionTask *task in downloadTasks)
                if (task.taskIdentifier == metadata.sessionTaskIdentifier || task.taskIdentifier == metadata.sessionTaskIdentifierPlist) {
                    findTask = task;
                    [app.listChangeTask setObject:@"cancelDownload" forKey:metadata.fileID];
                    [task cancel];
                }
            
            if (!findTask) {
                [app.listChangeTask setObject:@"cancelDownload" forKey:metadata.fileID];
                NSArray *object = [[NSArray alloc] initWithObjects:session, metadata, findTask, nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:networkingSessionNotification object:object];
            }
        }];
    }

    // UPLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"upload"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionUploadTask *task in uploadTasks)
                if (task.taskIdentifier == metadata.sessionTaskIdentifier ||  task.taskIdentifier == metadata.sessionTaskIdentifierPlist) {
                    findTask = task;
                    [app.listChangeTask setObject:@"cancelUpload" forKey:metadata.fileID];
                    [task cancel];
                }
            
            if (!findTask) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [app.listChangeTask setObject:@"cancelUpload" forKey:metadata.fileID];
                    NSArray *object = [[NSArray alloc] initWithObjects:session, metadata, findTask, nil];
                    [[NSNotificationCenter defaultCenter] postNotificationName:networkingSessionNotification object:object];
                });
            }
        }];
    }
}

- (void)stopTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        CCMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
        
        if (metadata)
            [self stopTaskButton:metadata];
    }
}

- (void)stopTaskButton:(CCMetadata *)metadata
{
    NSURLSession *session = [[CCNetworking sharedNetworking] getSessionfromSessionDescription:metadata.session];
    __block NSURLSessionTask *findTask;

    // UPLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"upload"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionUploadTask *task in uploadTasks)
                if (task.taskIdentifier == metadata.sessionTaskIdentifier || task.taskIdentifier == metadata.sessionTaskIdentifierPlist) {                    
                    [app.listChangeTask setObject:@"stopUpload" forKey:metadata.fileID];
                    findTask = task;
                    [task cancel];
                }
            
            if (!findTask) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [app.listChangeTask setObject:@"stopUpload" forKey:metadata.fileID];
                    NSArray *object = [[NSArray alloc] initWithObjects:session, metadata, findTask, nil];
                    [[NSNotificationCenter defaultCenter] postNotificationName:networkingSessionNotification object:object];
                });
            }
        }];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Shared =====
#pragma --------------------------------------------------------------------------------------------

- (void)readSharedSuccess:(CCMetadataNet *)metadataNet items:(NSDictionary *)items openWindow:(BOOL)openWindow
{
    [_hud hideHud];
    
    // change account ?
    TableAccount *record = [CCCoreData getActiveAccount];
    if([record.account isEqualToString:metadataNet.account] == NO)
        return;
    
    [CCCoreData updateShare:items sharesLink:app.sharesLink sharesUserAndGroup:app.sharesUserAndGroup activeAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
    
#ifdef CC
    
    /*** DROPBOX ***/

    if (openWindow && [app.typeCloud isEqualToString:typeCloudDropbox]) {
        
        if (_shareDB) {
                
            [_shareDB reloadData];
                
        } else {
            
            CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadataNet.fileID, app.activeAccount] context:nil];
            
            // Apriamo la view
            _shareDB = [[UIStoryboard storyboardWithName:@"CCShare" bundle:nil] instantiateViewControllerWithIdentifier:@"CCShareDB"];
            
            _shareDB.delegate = self;
            _shareDB.metadata = metadata;
            _shareDB.serverUrl = metadataNet.serverUrl;
            
            _shareDB.shareLink = [app.sharesLink objectForKey:metadata.fileID];

            [_shareDB setModalPresentationStyle:UIModalPresentationFormSheet];
            [self presentViewController:_shareDB animated:YES completion:nil];
        }
    }
    
#endif
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if (openWindow && ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud])) {
            
        if (_shareOC) {
                
            [_shareOC reloadData];
                
        } else {
            
            CCMetadata *metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", metadataNet.fileID, app.activeAccount] context:nil];
            
            // Apriamo la view
            _shareOC = [[UIStoryboard storyboardWithName:@"CCShare" bundle:nil] instantiateViewControllerWithIdentifier:@"CCShareOC"];
            
            _shareOC.delegate = self;
            _shareOC.metadata = metadata;
            _shareOC.serverUrl = metadataNet.serverUrl;
            
            _shareOC.shareLink = [app.sharesLink objectForKey:metadata.fileID];
            _shareOC.shareUserAndGroup = [app.sharesUserAndGroup objectForKey:metadata.fileID];
            
            [_shareOC setModalPresentationStyle:UIModalPresentationFormSheet];
            [self presentViewController:_shareOC animated:YES completion:nil];
        }
    }

    [self tableViewReload];
}

- (void)requestSharedByServer
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionReadShareServer;

    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

- (void)shareFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];
    
    [app messageNotification:@"_share_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];

    if (_shareOC)
        [_shareOC reloadData];
    
#ifdef CC
    if (_shareDB)
        [_shareDB reloadData];
#endif
    
    [self tableViewReload];
    
    if (errorCode == 401)
        [self changePasswordAccount];
}

// Dropbox
- (void)shareSuccessDropBox:(CCMetadataNet *)metadataNet link:(NSString *)link
{
    [_hud hideHud];
    
    // salviamo il link
    [CCCoreData setShareLink:link fileName:metadataNet.fileName serverUrl:metadataNet.serverUrl sharesLink:app.sharesLink activeAccount:app.activeAccount];
    
#ifdef CC
    if (_shareDB)
        [_shareDB reloadData];
#endif
    
    [self tableViewReload];
}

- (void)share:(CCMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) {
        
        metadataNet.action = actionShare;
        metadataNet.fileID = metadata.fileID;
        metadataNet.fileName = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:serverUrl activeUrl:app.activeUrl typeCloud:app.typeCloud];
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.password = password;
        metadataNet.selector = selectorShare;
        metadataNet.serverUrl = serverUrl;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }

    /*** DROPBOX ***/

    if ([app.typeCloud isEqualToString:typeCloudDropbox]) {
        
        metadataNet.fileID = metadata.fileID;
        metadataNet.fileName = metadata.fileName;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.serverUrl = serverUrl;
        
        NSString *shareLink = [app.sharesLink objectForKey:metadata.fileID];
        
        if ([shareLink length] > 0) {
                        
            [self shareSuccessDropBox:metadataNet link:shareLink];
            
        } else {
            
            metadataNet.action = actionShare;
            metadataNet.selector = selectorShare;
            
            [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        }
    }
    
    [_hud visibleHudTitle:NSLocalizedString(@"_creating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)unShareSuccess:(CCMetadataNet *)metadataNet
{
    [_hud hideHud];
    
    // rimuoviamo la condivisione da db
    [CCCoreData unShare:metadataNet.share fileName:metadataNet.fileName serverUrl:metadataNet.serverUrl sharesLink:app.sharesLink sharesUserAndGroup:app.sharesUserAndGroup activeAccount:app.activeAccount];
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([app.typeCloud isEqualToString:typeCloudNextcloud] && _shareOC)
        [_shareOC reloadData];

    if ([app.typeCloud isEqualToString:typeCloudOwnCloud] && _shareOC)
        [_shareOC reloadData];
    
#ifdef CC
    
    /*** DROPBOX ***/

    if ([app.typeCloud isEqualToString:typeCloudDropbox] && _shareDB)
        [_shareDB reloadData];
    
#endif
    
    [self tableViewReload];
}

- (void)unShare:(NSString *)share metadata:(CCMetadata *)metadata serverUrl:(NSString *)serverUrl
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionUnShare;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = metadata.fileName;
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.selector = selectorUnshare;
    metadataNet.serverUrl = serverUrl;
    metadataNet.share = share;
   
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleHudTitle:NSLocalizedString(@"_updating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)updateShare:(NSString *)share metadata:(CCMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password expirationTime:(NSString *)expirationTime permission:(NSInteger)permission
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) {
        
        metadataNet.action = actionUpdateShare;
        metadataNet.fileID = metadata.fileID;
        metadataNet.expirationTime = expirationTime;
        metadataNet.password = password;
        metadataNet.selector = selectorUpdateShare;
        metadataNet.serverUrl = serverUrl;
        metadataNet.share = share;
        metadataNet.sharePermission = permission;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }

    [_hud visibleHudTitle:NSLocalizedString(@"_updating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)getUserAndGroupSuccess:(CCMetadataNet *)metadataNet items:(NSArray *)items
{
    [_hud hideHud];
    
    if (_shareOC)
        [_shareOC reloadUserAndGroup:items];
}

- (void)getUserAndGroupFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];
    
    [app messageNotification:@"_error_" description:message visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
}

- (void)getUserAndGroup:(NSString *)find
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    /*** NEXTCLOUD OWNCLOUD ***/
    
    if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud]) {
        
        metadataNet.action = actionGetUserAndGroup;
        metadataNet.options = find;
        metadataNet.selector = selectorGetUserAndGroup;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
    
    [_hud visibleIndeterminateHud];
}

- (void)shareUserAndGroup:(NSString *)user shareeType:(NSInteger)shareeType permission:(NSInteger)permission metadata:(CCMetadata *)metadata directoryID:(NSString *)directoryID serverUrl:(NSString *)serverUrl
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];

    metadataNet.action = actionShareWith;
    metadataNet.fileID = metadata.fileID;
    metadataNet.directoryID = directoryID;
    metadataNet.fileName = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:serverUrl activeUrl:app.activeUrl typeCloud:app.typeCloud];
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.serverUrl = serverUrl;
    metadataNet.selector = selectorShare;
    metadataNet.share = user;
    metadataNet.shareeType = shareeType;
    metadataNet.sharePermission = permission;

    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleHudTitle:NSLocalizedString(@"_creating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)openWindowShare:(CCMetadata *)metadata serverUrl:(NSString *)serverUrl
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionReadShareServer;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = metadata.fileName;
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.selector = selectorOpenWindowShare;
    metadataNet.serverUrl = serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleIndeterminateHud];
}

- (void)tapActionShared:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    CCMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (metadata)
        [self openWindowShare:metadata serverUrl:_localServerUrl];
}

- (void)tapActionConnectionMounted:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    CCMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (metadata) {
        
        CCShareInfoCMOC *vc = [[UIStoryboard storyboardWithName:@"CCShare" bundle:nil] instantiateViewControllerWithIdentifier:@"CCShareInfoCMOC"];
        
        vc.metadata = metadata;
        
        [vc setModalPresentationStyle:UIModalPresentationFormSheet];
        [self presentViewController:vc animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Favorite =====
#pragma --------------------------------------------------------------------------------------------

- (void)addFavorite:(CCMetadata *)metadata
{
    if (metadata.errorPasscode || !metadata.uuid) return;
    
    if ([metadata.type isEqualToString:metadataType_file])
        [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selectorAddFavorite selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
    
    if ([metadata.type isEqualToString:metadataType_model])
        [CCCoreData addFavorite:metadata.fileID activeAccount:app.activeAccount];
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadata.fileID];
    if (indexPath) [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)removeFavorite:(CCMetadata *)metadata
{
    [CCCoreData removeFavoriteFromFileID:metadata.fileID activeAccount:app.activeAccount];
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadata.fileID];
    if (indexPath) [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadTableFavorite" object:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Local =====
#pragma --------------------------------------------------------------------------------------------

- (void)addLocal:(CCMetadata *)metadata
{
    if (metadata.errorPasscode || !metadata.uuid) return;
    
    if ([metadata.type isEqualToString:metadataType_file])
        [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selectorAddLocal selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
    
    if ([metadata.type isEqualToString:metadataType_model]) {
        
        [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileName] toPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryLocal], metadata.fileName]];
        
        [app messageNotification:@"_add_local_" description:@"_file_saved_local_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadTableFavorite" object:nil];
    }
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadata.fileID];
    if (indexPath) [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Reload =====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadFile:(CCMetadata *)metadata
{
    [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selectorReload selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Open in... =====
#pragma --------------------------------------------------------------------------------------------

- (void)openIn:(CCMetadata *)metadata
{
    [[CCNetworking sharedNetworking] downloadFile:metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selectorOpenIn selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadata.fileID];
    if (indexPath) [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Browse Images =====
#pragma --------------------------------------------------------------------------------------------

- (void)browseImages
{
    NSArray *records = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@) AND ((typeFile == %@) OR (typeFile == %@))", app.activeAccount, _localDirectoryID, metadataTypeFile_image, metadataTypeFile_video] context:nil];
    
    if ([records count] == 0 || [self shouldPerformSegue:_localServerUrl] == NO) {
        
        [app messageNotification:@"_info_" description:@"_no_photo_load_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeInfo];
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        _metadataSegue.fileID = nil;
        _metadataSegue.directoryID = _localDirectoryID;
        _metadataSegue.sessionSelector = selectorBrowseImages;
        _metadataSegue.typeFile = metadataTypeFile_image;
        
        [self performSegueWithIdentifier:@"segueDetail" sender:self];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Order Table & GroupBy & DirectoryOnTop =====
#pragma --------------------------------------------------------------------------------------------

- (void)orderTable:(NSString *)order
{
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationName:@"clearDateReadDataSource" object:nil];
    
    [CCUtility setOrderSettings:order];
    
    // refresh
    [self getDataSourceWithReloadTableView:_localDirectoryID fileID:nil selector:nil];
    // new menu
    [self createReMainMenu];
}

- (void)ascendingTable:(BOOL)ascending
{
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationName:@"clearDateReadDataSource" object:nil];
    
    [CCUtility setAscendingSettings:ascending];
    
    // refresh
    [self getDataSourceWithReloadTableView:_localDirectoryID fileID:nil selector:nil];
    // new menu
    [self createReMainMenu];
}

- (void)directoryOnTop:(BOOL)directoryOnTop
{
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationName:@"clearDateReadDataSource" object:nil];
    
    [CCUtility setDirectoryOnTop:directoryOnTop];
    
    // refresh
    [self getDataSourceWithReloadTableView:_localDirectoryID fileID:nil selector:nil];
    // new menu
    [self createReMainMenu];
}

- (void)tableGroupBy:(NSString *)groupBy
{
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationName:@"clearDateReadDataSource" object:nil];
    
    [CCUtility setGroupBySettings:groupBy];
    
    // refresh
    [self getDataSourceWithReloadTableView:_localDirectoryID fileID:nil selector:nil];
    // new menu
    [self createReMainMenu];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Menu change User ====
#pragma --------------------------------------------------------------------------------------------

- (void)menuChangeUser
{
    if (app.reSelectMenu.isOpen || app.reMainMenu.isOpen)
        return;
    
    if ([app.netQueue operationCount] > 0 || [app.netQueueDownload operationCount] > 0 || [app.netQueueDownloadWWan operationCount] > 0 || [app.netQueueUpload operationCount] > 0 || [app.netQueueUploadWWan operationCount] > 0 || [CCCoreData countTableAutomaticUploadForAccount:app.activeAccount selector:nil] > 0) {
        
        [app messageNotification:@"_transfers_in_queue_" description:nil visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeInfo];
        return;
    }
    
    NSArray *listTableAccount = [CCCoreData getAllTableAccount];
    NSMutableArray *menuArray = [[NSMutableArray alloc] init];
    
    for (TableAccount *record in listTableAccount) {
     
        if ([record.account isEqualToString:app.activeAccount]) continue;
        
        CCMenuItem *item = [[CCMenuItem alloc] init];
        
        item.title = [record.account stringByTruncatingToWidth:self.view.bounds.size.width - 100 withFont:[UIFont systemFontOfSize:12.0] atEnd:YES];
        item.argument = record.account;
        
        /*** DROPBOX ***/

        if ([record.typeCloud isEqualToString:typeCloudDropbox]) item.image = [UIImage imageNamed:image_typeCloudDropbox];
        
        /*** NEXTCLOUD OWNCLOUD ***/
        
        if ([record.typeCloud isEqualToString:typeCloudNextcloud]) item.image = [UIImage imageNamed:image_typeCloudNextcloud];
        if ([record.typeCloud isEqualToString:typeCloudOwnCloud]) item.image = [UIImage imageNamed:image_typeCloudOwnCloud];
        
        item.target = self;
        item.action = @selector(changeDefaultAccount:);
        
        [menuArray addObject:item];
    }
    
    if ([menuArray count] == 0)
        return;
    
    OptionalConfiguration options;
    Color textColor, backgroundColor;
    
    textColor.R = 0;
    textColor.G = 0;
    textColor.B = 0;
    
    backgroundColor.R = 1;
    backgroundColor.G = 1;
    backgroundColor.B = 1;
    
    options.arrowSize = 9;
    options.marginXSpacing = 7;
    options.marginYSpacing = 10;
    options.intervalSpacing = 20;
    options.menuCornerRadius = 6.5;
    options.maskToBackground = NO;
    options.shadowOfMenu = YES;
    options.hasSeperatorLine = YES;
    options.seperatorLineHasInsets = YES;
    options.textColor = textColor;
    options.menuBackgroundColor = backgroundColor;
    
    [CCMenu setTitleFont:[UIFont systemFontOfSize:12.0]];
    [CCMenu showMenuInView:self.navigationController.view fromRect:self.view.frame menuItems:menuArray withOptions:options];
}

- (void)changeDefaultAccount:(CCMenuItem *)sender
{
    [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:NO];
    
    // STOP, erase all in  queue networking
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    
        TableAccount *tableAccount = [CCCoreData setActiveAccount:[sender argument]];
        if (tableAccount)
            [app settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activePassword:tableAccount.password activeUID:tableAccount.uid activeAccessToken:tableAccount.token typeCloud:tableAccount.typeCloud];
    
        // go to home sweet home
        [[NSNotificationCenter defaultCenter] postNotificationName:@"initializeMain" object:nil];
        
        [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== ReMenu ====
#pragma --------------------------------------------------------------------------------------------

- (void)createReMenuBackgroundView:(REMenu *)menu
{
    __block CGFloat navigationBarH = self.navigationController.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;

    _reMenuBackgroundView.frame = CGRectMake(0, navigationBarH, self.view.frame.size.width, self.view.frame.size.height);
        
    [UIView animateWithDuration:0.2 animations:^{
                
        float height = (self.view.frame.size.height + navigationBarH) - (menu.menuView.frame.size.height - self.navigationController.navigationBar.frame.size.height + 3);
        
        if (height < self.tabBarController.tabBar.frame.size.height)
            height = self.tabBarController.tabBar.frame.size.height;
        
        _reMenuBackgroundView.frame = CGRectMake(0, self.view.frame.size.height + navigationBarH, self.view.frame.size.width, - height);
        
        [self.tabBarController.view addSubview:_reMenuBackgroundView];
    }];
}

- (void)createReMainMenu
{
    NSString *ordinamento;
    NSString *groupBy = _directoryGroupBy;
    __block NSString *nuovoOrdinamento;
    NSString *titoloNuovo, *titoloAttuale;
    BOOL ascendente;
    __block BOOL nuovoAscendente;
    UIImage *image;
    
    // ITEM THUMBS ------------------------------------------------------------------------------------------------------
    
    if (app.browseItem == nil) app.browseItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_browse_images_", nil)
                                                                                         subtitle:@""
                                                                                            image:[UIImage imageNamed:image_thumbs]
                                                                                 highlightedImage:nil
                                                                                           action:^(REMenuItem *item) {
                                                                                               
                                                                                               [self browseImages];
                                                                                           }];
    
    else app.browseItem = [app.browseItem initWithTitle:NSLocalizedString(@"_browse_images_", nil)
                                                               subtitle:@""
                                                                  image:[UIImage imageNamed:image_thumbs]
                                                       highlightedImage:nil
                                                                 action:^(REMenuItem *item) {
                                                                     
                                                                    [self browseImages];
                                                                     
                                                                 }];

    
    // ITEM SELECT ----------------------------------------------------------------------------------------------------
    
    if (app.selezionaItem == nil) app.selezionaItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_select_", nil)
                                                                                               subtitle:@""
                                                                                                  image:[UIImage imageNamed:image_seleziona]
                                                                                       highlightedImage:nil
                                                                                                 action:^(REMenuItem *item) {
                                                                                                     
                                                                                                     if ([_sectionDataSource.allRecordsDataSource count] > 0) {
                                                                                                         [self tableViewSelect:YES];
                                                                                                     }
                                                                                                 }];
    else app.selezionaItem = [app.selezionaItem initWithTitle:NSLocalizedString(@"_select_", nil)
                                                                     subtitle:@""
                                                                        image:[UIImage imageNamed:image_seleziona]
                                                             highlightedImage:nil
                                                                       action:^(REMenuItem *item) {
                                                                           
                                                                           if ([_sectionDataSource.allRecordsDataSource count] > 0)
                                                                               [self tableViewSelect:YES];
                                                                       }];
    
    // ITEM ORDER ----------------------------------------------------------------------------------------------------
    
    ordinamento = _directoryOrder;
    if ([ordinamento isEqualToString:@"fileName"]) {
        
        image = [UIImage imageNamed:image_MenuOrdeyByDate];
        titoloNuovo = NSLocalizedString(@"_order_by_date_", nil);
        titoloAttuale = NSLocalizedString(@"_current_order_name_", nil);
        nuovoOrdinamento = @"fileDate";
    }
    
    if ([ordinamento isEqualToString:@"fileDate"]) {
        
        image = [UIImage imageNamed:image_MenuOrderByFileName];
        titoloNuovo = NSLocalizedString(@"_order_by_name_", nil);
        titoloAttuale = NSLocalizedString(@"_current_order_date_", nil);
        nuovoOrdinamento = @"fileName";
    }
    
    if (app.ordinaItem == nil) app.ordinaItem = [[REMenuItem alloc] initWithTitle:titoloNuovo
                                                                                         subtitle:titoloAttuale
                                                                                            image:image
                                                                                 highlightedImage:nil
                                                                                           action:^(REMenuItem *item) {
                                                                                               [self orderTable:nuovoOrdinamento];
                                                                                           }];
    else app.ordinaItem = [app.ordinaItem initWithTitle:titoloNuovo
                                                               subtitle:titoloAttuale
                                                                  image:image
                                                       highlightedImage:nil
                                                                 action:^(REMenuItem *item) {
                                                                     [self orderTable:nuovoOrdinamento];
                                                                 }];
    
    // ITEM ASCENDING -----------------------------------------------------------------------------------------------------
    
    ascendente = [CCUtility getAscendingSettings];
    
    if (ascendente)  {
        
        image = [UIImage imageNamed:image_MenuOrdinamentoDiscendente];
        titoloNuovo = NSLocalizedString(@"_sort_descending_", nil);
        titoloAttuale = NSLocalizedString(@"_current_sort_ascending_", nil);
        nuovoAscendente = false;
    }
    
    if (!ascendente) {
        
        image = [UIImage imageNamed:image_MenuOrdinamentoAscendente];
        titoloNuovo = NSLocalizedString(@"_sort_ascending_", nil);
        titoloAttuale = NSLocalizedString(@"_current_sort_descending_", nil);
        nuovoAscendente = true;
    }
    
    if (app.ascendenteItem == nil) app.ascendenteItem = [[REMenuItem alloc] initWithTitle:titoloNuovo
                                                                                                 subtitle:titoloAttuale
                                                                                                    image:image
                                                                                         highlightedImage:nil
                                                                                                   action:^(REMenuItem *item) {
                                                                                                       [self ascendingTable:nuovoAscendente];
                                                                                                   }];
    else app.ascendenteItem = [app.ascendenteItem initWithTitle:titoloNuovo
                                                                       subtitle:titoloAttuale
                                                                          image:image
                                                               highlightedImage:nil
                                                                         action:^(REMenuItem *item) {
                                                                             [self ascendingTable:nuovoAscendente];
                                                                         }];
    
    // ITEM ALPHABETIC -----------------------------------------------------------------------------------------------------
    
    if ([groupBy isEqualToString:@"alphabetic"])  { titoloNuovo = NSLocalizedString(@"_group_alphabetic_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_group_alphabetic_no_", nil); }
    
    if (app.alphabeticItem == nil) app.alphabeticItem = [[REMenuItem alloc] initWithTitle:titoloNuovo
                                                                                                 subtitle:@""
                                                                                                    image:[UIImage imageNamed:image_MenuGroupByAlphabetic]
                                                                                         highlightedImage:nil
                                                                                                   action:^(REMenuItem *item) {
                                                                                                       if ([groupBy isEqualToString:@"alphabetic"]) [self tableGroupBy:@"none"];
                                                                                                       else [self tableGroupBy:@"alphabetic"];
                                                                                                   }];
    else app.alphabeticItem = [app.alphabeticItem initWithTitle:titoloNuovo
                                                                       subtitle:@""
                                                                          image:[UIImage imageNamed:image_MenuGroupByAlphabetic]
                                                               highlightedImage:nil
                                                                         action:^(REMenuItem *item) {
                                                                             if ([groupBy isEqualToString:@"alphabetic"]) [self tableGroupBy:@"none"];
                                                                             else [self tableGroupBy:@"alphabetic"];
                                                                         }];
    
    // ITEM TYPEFILE -------------------------------------------------------------------------------------------------------
    
    if ([groupBy isEqualToString:@"typefile"])  { titoloNuovo = NSLocalizedString(@"_group_typefile_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_group_typefile_no_", nil); }
    
    if (app.typefileItem == nil) app.typefileItem = [[REMenuItem alloc] initWithTitle:titoloNuovo
                                                                                                 subtitle:@""
                                                                                                    image:[UIImage imageNamed:image_MenuGroupByTypeFile]
                                                                                         highlightedImage:nil
                                                                                                   action:^(REMenuItem *item) {
                                                                                                       if ([groupBy isEqualToString:@"typefile"]) [self tableGroupBy:@"none"];
                                                                                                       else [self tableGroupBy:@"typefile"];
                                                                                                   }];
    else app.typefileItem = [app.typefileItem initWithTitle:titoloNuovo
                                                                       subtitle:@""
                                                                          image:[UIImage imageNamed:image_MenuGroupByTypeFile]
                                                               highlightedImage:nil
                                                                         action:^(REMenuItem *item) {
                                                                             if ([groupBy isEqualToString:@"typefile"]) [self tableGroupBy:@"none"];
                                                                             else [self tableGroupBy:@"typefile"];
                                                                         }];

    // ITEM DATE -------------------------------------------------------------------------------------------------------
    
    if ([groupBy isEqualToString:@"date"])  { titoloNuovo = NSLocalizedString(@"_group_date_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_group_date_no_", nil); }
    
    if (app.dateItem == nil) app.dateItem = [[REMenuItem alloc] initWithTitle:titoloNuovo
                                                                                     subtitle:@""
                                                                                        image:[UIImage imageNamed:image_MenuGroupByDate]
                                                                             highlightedImage:nil
                                                                                       action:^(REMenuItem *item) {
                                                                                           if ([groupBy isEqualToString:@"date"]) [self tableGroupBy:@"none"];
                                                                                                   else [self tableGroupBy:@"date"];
                                                                                            }];
    else app.dateItem = [app.dateItem initWithTitle:titoloNuovo
                                                           subtitle:@""
                                                              image:[UIImage imageNamed:image_MenuGroupByDate]
                                                   highlightedImage:nil
                                                             action:^(REMenuItem *item) {
                                                                if ([groupBy isEqualToString:@"date"]) [self tableGroupBy:@"none"];
                                                                    else [self tableGroupBy:@"date"];
                                                                }];

    // ITEM DIRECTORY ON TOP ------------------------------------------------------------------------------------------------
    
    if ([CCUtility getDirectoryOnTop])  { titoloNuovo = NSLocalizedString(@"_directory_on_top_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_directory_on_top_no_", nil); }
    
    if (app.directoryOnTopItem == nil) app.directoryOnTopItem = [[REMenuItem alloc] initWithTitle:titoloNuovo
                                                                                         subtitle:@""
                                                                                            image:[UIImage imageNamed:image_MenuDirectoryOnTop]
                                                                                 highlightedImage:nil
                                                                                           action:^(REMenuItem *item) {
                                                                                               
                                                                                               if ([CCUtility getDirectoryOnTop]) [self directoryOnTop:NO];
                                                                                               else [self directoryOnTop:YES];
                                                                                           }];
    else app.directoryOnTopItem = [app.directoryOnTopItem initWithTitle:titoloNuovo
                                                               subtitle:@""
                                                                  image:[UIImage imageNamed:image_MenuDirectoryOnTop]
                                                       highlightedImage:nil
                                                                 action:^(REMenuItem *item) {
                                                                     
                                                                     if ([CCUtility getDirectoryOnTop]) [self directoryOnTop:NO];
                                                                     else [self directoryOnTop:YES];
                                                                 }];

    // REMENU --------------------------------------------------------------------------------------------------------------

    if (app.reMainMenu == nil) app.reMainMenu = [[REMenu alloc] initWithItems:@[app.browseItem, app.selezionaItem, app.ordinaItem, app.ascendenteItem, app.alphabeticItem, app.typefileItem, app.dateItem, app.directoryOnTopItem]];
    else app.reMainMenu = [app.reMainMenu initWithItems:@[app.browseItem, app.selezionaItem, app.ordinaItem, app.ascendenteItem, app.alphabeticItem, app.typefileItem, app.dateItem, app.directoryOnTopItem]];
    
    app.reMainMenu.imageOffset = CGSizeMake(5, -1);
    
    app.reMainMenu.separatorOffset = CGSizeMake(50.0, 0.0);
    app.reMainMenu.imageOffset = CGSizeMake(0, 0);
    app.reMainMenu.waitUntilAnimationIsComplete = NO;
    
    app.reMainMenu.separatorHeight = 0.5;
    app.reMainMenu.separatorColor = COLOR_SEPARATOR_TABLE;
    
    app.reMainMenu.backgroundColor = COLOR_BAR;
    app.reMainMenu.textColor = [UIColor blackColor];
    app.reMainMenu.textAlignment = NSTextAlignmentLeft;
    app.reMainMenu.textShadowColor = nil;
    app.reMainMenu.textOffset = CGSizeMake(50, 0.0);
    app.reMainMenu.font = [UIFont systemFontOfSize:14.0];
    
    app.reMainMenu.highlightedBackgroundColor = COLOR_SELECT_BACKGROUND;
    app.reMainMenu.highlightedSeparatorColor = nil;
    app.reMainMenu.highlightedTextColor = [UIColor blackColor];
    app.reMainMenu.highlightedTextShadowColor = nil;
    app.reMainMenu.highlightedTextShadowOffset = CGSizeMake(0, 0);
    
    app.reMainMenu.subtitleTextColor = [UIColor colorWithWhite:0.425 alpha:1];
    app.reMainMenu.subtitleTextAlignment = NSTextAlignmentLeft;
    app.reMainMenu.subtitleTextShadowColor = nil;
    app.reMainMenu.subtitleTextShadowOffset = CGSizeMake(0, 0.0);
    app.reMainMenu.subtitleTextOffset = CGSizeMake(50, 0.0);
    app.reMainMenu.subtitleFont = [UIFont systemFontOfSize:12.0];
    
    app.reMainMenu.subtitleHighlightedTextColor = [UIColor lightGrayColor];
    app.reMainMenu.subtitleHighlightedTextShadowColor = nil;
    app.reMainMenu.subtitleHighlightedTextShadowOffset = CGSizeMake(0, 0);
    
    app.reMainMenu.borderWidth = 0.3;
    app.reMainMenu.borderColor =  [UIColor lightGrayColor];
    
    app.reMainMenu.animationDuration = 0.2;
    app.reMainMenu.closeAnimationDuration = 0.2;
    
    app.reMainMenu.bounce = NO;
    
    [app.reMainMenu setClosePreparationBlock:^{
        
        // Backgroun reMenu (Gesture)
        [_reMenuBackgroundView removeFromSuperview];
        [app.controlCenter disableSingleFingerTap];
        [_reMenuBackgroundView removeGestureRecognizer:_singleFingerTap];
    }];
}

- (void)toggleReMainMenu
{
    if (app.reMainMenu.isOpen) {
        
        [app.reMainMenu close];
        
    } else {
        
        [app.reMainMenu showFromNavigationController:self.navigationController];
        
        // Backgroun reMenu & (Gesture)
        [self createReMenuBackgroundView:app.reMainMenu];
        [app.controlCenter enableSingleFingerTap:@selector(toggleReMainMenu) target:self];
        _singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleReMainMenu)];
        [_reMenuBackgroundView addGestureRecognizer:_singleFingerTap];
    }
}

- (void)createReSelectMenu
{
    // ITEM DELETE ------------------------------------------------------------------------------------------------------
    
    if (app.deleteItem == nil) app.deleteItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_delete_selected_files_", nil)
                                                                                         subtitle:@""
                                                                                            image:[UIImage imageNamed:image_deleteSelectedFiles]
                                                                                 highlightedImage:nil
                                                                                           action:^(REMenuItem *item) {
                                                                                               [self deleteSelectionFile];
                                                                                           }];
    else app.deleteItem = [app.deleteItem initWithTitle:NSLocalizedString(@"_delete_selected_files_", nil)
                                                               subtitle:@""
                                                                  image:[UIImage imageNamed:image_deleteSelectedFiles]
                                                       highlightedImage:nil
                                                                 action:^(REMenuItem *item) {
                                                                     [self deleteSelectionFile];
                                                                 }];
    
    
    // ITEM MOVE ------------------------------------------------------------------------------------------------------
    
    if (app.moveItem == nil) app.moveItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_move_selected_files_", nil)
                                                                                               subtitle:@""
                                                                                                  image:[UIImage imageNamed:image_moveSelectedFiles]
                                                                                       highlightedImage:nil
                                                                                                 action:^(REMenuItem *item) {
                                                                                                     [self moveOpenWindow:[self.tableView indexPathsForSelectedRows]];
                                                                                                 }];
    else app.moveItem = [app.moveItem initWithTitle:NSLocalizedString(@"_move_selected_files_", nil)
                                                                     subtitle:@""
                                                                        image:[UIImage imageNamed:image_moveSelectedFiles]
                                                             highlightedImage:nil
                                                                       action:^(REMenuItem *item) {
                                                                           [self moveOpenWindow:[self.tableView indexPathsForSelectedRows]];
                                                                       }];
    
    // ITEM ENCRYPTED ------------------------------------------------------------------------------------------------------
    
    if (app.encryptItem == nil) app.encryptItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_encrypted_selected_files_", nil)
                                                                                     subtitle:@""
                                                                                        image:[UIImage imageNamed:image_encryptedSelectedFiles]
                                                                             highlightedImage:nil
                                                                                       action:^(REMenuItem *item) {
                                                                                           [self performSelector:@selector(encryptedSelectedFiles) withObject:nil afterDelay:0.1];
                                                                                       }];
    else app.encryptItem = [app.encryptItem initWithTitle:NSLocalizedString(@"_encrypted_selected_files_", nil)
                                                           subtitle:@""
                                                              image:[UIImage imageNamed:image_encryptedSelectedFiles]
                                                   highlightedImage:nil
                                                             action:^(REMenuItem *item) {
                                                                 [self performSelector:@selector(encryptedSelectedFiles) withObject:nil afterDelay:0.1];
                                                             }];
    
    // ITEM DECRYPTED ----------------------------------------------------------------------------------------------------
    
    if (app.decryptItem == nil) app.decryptItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_decrypted_selected_files_", nil)
                                                                                           subtitle:@""
                                                                                              image:[UIImage imageNamed:image_decryptedSelectedFiles]
                                                                                   highlightedImage:nil
                                                                                             action:^(REMenuItem *item) {
                                                                                                 [self performSelector:@selector(decryptedSelectedFiles) withObject:nil afterDelay:0.1];
                                                                                             }];
    else app.decryptItem = [app.decryptItem initWithTitle:NSLocalizedString(@"_decrypted_selected_files_", nil)
                                                                 subtitle:@""
                                                                    image:[UIImage imageNamed:image_decryptedSelectedFiles]
                                                         highlightedImage:nil
                                                                   action:^(REMenuItem *item) {
                                                                       [self performSelector:@selector(decryptedSelectedFiles) withObject:nil afterDelay:0.1];
                                                                   }];


    // ITEM DOWNLOAD ----------------------------------------------------------------------------------------------------
    
    if (app.downloadItem == nil) app.downloadItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_download_selected_files_", nil)
                                                                                           subtitle:@""
                                                                                              image:[UIImage imageNamed:image_downloadSelectedFiles]
                                                                                   highlightedImage:nil
                                                                                             action:^(REMenuItem *item) {
                                                                                                 [self downloadSelectedFiles];
                                                                                             }];
    else app.downloadItem = [app.downloadItem initWithTitle:NSLocalizedString(@"_download_selected_files_", nil)
                                                                 subtitle:@""
                                                                    image:[UIImage imageNamed:image_downloadSelectedFiles]
                                                         highlightedImage:nil
                                                                   action:^(REMenuItem *item) {
                                                                       [self downloadSelectedFiles];
                                                                   }];
    
    // ITEM SAVE IMAGE & VIDEO -------------------------------------------------------------------------------------------
    
    if (app.saveItem == nil) app.saveItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_save_selected_files_", nil)
                                                                                             subtitle:@""
                                                                                                image:[UIImage imageNamed:image_saveSelectedFiles]
                                                                                     highlightedImage:nil
                                                                                               action:^(REMenuItem *item) {
                                                                                                   [self saveSelectedFiles];
                                                                                               }];
    else app.saveItem = [app.saveItem initWithTitle:NSLocalizedString(@"_save_selected_files_", nil)
                                                                   subtitle:@""
                                                                      image:[UIImage imageNamed:image_saveSelectedFiles]
                                                           highlightedImage:nil
                                                                     action:^(REMenuItem *item) {
                                                                         [self saveSelectedFiles];
                                                                     }];


    // REMENU --------------------------------------------------------------------------------------------------------------
    
    if (app.reSelectMenu == nil)
        app.reSelectMenu = [[REMenu alloc] initWithItems:@[app.deleteItem,app.moveItem, app.encryptItem, app.decryptItem, app.downloadItem, app.saveItem]];
    else
        app.reSelectMenu = [app.reSelectMenu initWithItems:@[app.deleteItem,app.moveItem, app.encryptItem, app.decryptItem, app.downloadItem, app.saveItem]];
    
    app.reSelectMenu.imageOffset = CGSizeMake(5, -1);
    
    app.reSelectMenu.separatorOffset = CGSizeMake(50.0, 0.0);
    app.reSelectMenu.imageOffset = CGSizeMake(0, 0);
    app.reSelectMenu.waitUntilAnimationIsComplete = NO;
    
    app.reSelectMenu.separatorHeight = 0.5;
    app.reSelectMenu.separatorColor = COLOR_SEPARATOR_TABLE;
    
    app.reSelectMenu.backgroundColor = COLOR_BAR;
    app.reSelectMenu.textColor = [UIColor blackColor];
    app.reSelectMenu.textAlignment = NSTextAlignmentLeft;
    app.reSelectMenu.textShadowColor = nil;
    app.reSelectMenu.textOffset = CGSizeMake(50, 0.0);
    app.reSelectMenu.font = [UIFont systemFontOfSize:14.0];
    
    app.reSelectMenu.highlightedBackgroundColor = COLOR_SELECT_BACKGROUND;
    app.reSelectMenu.highlightedSeparatorColor = nil;
    app.reSelectMenu.highlightedTextColor = [UIColor blackColor];
    app.reSelectMenu.highlightedTextShadowColor = nil;
    app.reSelectMenu.highlightedTextShadowOffset = CGSizeMake(0, 0);
    
    app.reSelectMenu.subtitleTextColor = [UIColor colorWithWhite:0.425 alpha:1.000];
    app.reSelectMenu.subtitleTextAlignment = NSTextAlignmentLeft;
    app.reSelectMenu.subtitleTextShadowColor = nil;
    app.reSelectMenu.subtitleTextShadowOffset = CGSizeMake(0, 0.0);
    app.reSelectMenu.subtitleTextOffset = CGSizeMake(50, 0.0);
    app.reSelectMenu.subtitleFont = [UIFont systemFontOfSize:12.0];
    
    app.reSelectMenu.subtitleHighlightedTextColor = [UIColor lightGrayColor];
    app.reSelectMenu.subtitleHighlightedTextShadowColor = nil;
    app.reSelectMenu.subtitleHighlightedTextShadowOffset = CGSizeMake(0, 0);
    
    app.reSelectMenu.borderWidth = 0.3;
    app.reSelectMenu.borderColor =  [UIColor lightGrayColor];
    
    app.reSelectMenu.closeAnimationDuration = 0.2;
    app.reSelectMenu.animationDuration = 0.2;

    app.reSelectMenu.bounce = NO;
    
    [app.reSelectMenu setClosePreparationBlock:^{
        
        // Backgroun reMenu (Gesture)
        [_reMenuBackgroundView removeFromSuperview];
        [_reMenuBackgroundView removeGestureRecognizer:_singleFingerTap];
    }];
}

- (void)toggleReSelectMenu
{
    if (app.reSelectMenu.isOpen) {
        
        [app.reSelectMenu close];
        
    } else {
        
        [app.reSelectMenu showFromNavigationController:self.navigationController];
        
        // Backgroun reMenu & (Gesture)
        [self createReMenuBackgroundView:app.reSelectMenu];
        _singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleReSelectMenu)];
        [_reMenuBackgroundView addGestureRecognizer:_singleFingerTap];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Long Press Recognized Table View / Menu Controller =====
#pragma --------------------------------------------------------------------------------------------

- (void)onLongPressTableView:(UILongPressGestureRecognizer*)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        
        UITableView *tableView = (UITableView*)self.view;
        CGPoint touchPoint = [recognizer locationInView:self.view];
        NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:touchPoint];
        
        if (indexPath)
            _metadata = [self getMetadataFromSectionDataSource:indexPath];
        else
            _metadata = nil;
        
        [self becomeFirstResponder];
        
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        
        UIMenuItem *copyFileItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_copy_file_", nil) action:@selector(copyFile:)];
        UIMenuItem *copyFilesItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_copy_files_", nil) action:@selector(copyFiles:)];

        UIMenuItem *pasteFileItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_file_", nil) action:@selector(pasteFile:)];
        UIMenuItem *pasteFileEncryptedItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_file_encrypted_", nil) action:@selector(pasteFileEncrypted:)];
        
        UIMenuItem *pasteFilesItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_files_", nil) action:@selector(pasteFiles:)];
        UIMenuItem *pasteFilesEncryptedItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_files_encrypted_", nil) action:@selector(pasteFilesEncrypted:)];
        
        [menuController setMenuItems:[NSArray arrayWithObjects:copyFileItem, copyFilesItem, pasteFileItem, pasteFilesItem, pasteFileEncryptedItem, pasteFilesEncryptedItem, nil]];
        [menuController setTargetRect:CGRectMake(touchPoint.x, touchPoint.y, 0.0f, 0.0f) inView:tableView];
        [menuController setMenuVisible:YES animated:YES];
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (@selector(copyFile:) == action) {
        
        if (_isSelectedMode == NO && _metadata) {
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, _metadata.fileID]]) return YES;
            else return NO;
            
        } else return NO;
    }
    
    if (@selector(copyFiles:) == action) {
        
        if (_isSelectedMode) {
            
            BOOL isValid = NO;
            
            NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
            
            for (CCMetadata *metadata in selectedMetadatas) {
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]])
                    isValid = YES;
            }
            
            return isValid;
            
        } else return NO;
    }

    if (@selector(pasteFile:) == action || @selector(pasteFileEncrypted:) == action) {
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray *items = [pasteboard items];
        
        if ([items count] == 1) {
            
            // key : it.twsweb.Crypto-Cloud.CCMetadata      Value : (NSData) metadata
            
            NSDictionary *dic = [items objectAtIndex:0];
            
            NSData *dataMetadata = [dic objectForKey:@"it.twsweb.Crypto-Cloud.CCMetadata"];
            CCMetadata *metadata = [NSKeyedUnarchiver unarchiveObjectWithData:dataMetadata];
            
            TableAccount *account = [CCCoreData getTableAccountFromAccount:metadata.account];
            NSString *directoryUser = [CCUtility getDirectoryActiveUser:account.user activeUrl:account.url];
            
            if (directoryUser) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, metadata.fileID]])
                    return YES;
            }
            
            return NO;

        } else return NO;
    }
    
    if (@selector(pasteFiles:) == action || @selector(pasteFilesEncrypted:) == action) {
        
        BOOL isValid = NO;
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray *items = [pasteboard items];
        
        if ([items count] <= 1) return NO;
        
        for (NSDictionary *dic in items) {
            
            // key : it.twsweb.Crypto-Cloud.CCMetadata      Value : (NSData) metadata
            
            NSData *dataMetadata = [dic objectForKey:@"it.twsweb.Crypto-Cloud.CCMetadata"];
            CCMetadata *metadata = [NSKeyedUnarchiver unarchiveObjectWithData:dataMetadata];
            
            TableAccount *account = [CCCoreData getTableAccountFromAccount:metadata.account];
            NSString *directoryUser = [CCUtility getDirectoryActiveUser:account.user activeUrl:account.url];
            
            if (directoryUser) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, metadata.fileID]])
                    isValid = YES;
            }
        }
        
        return isValid;
    }
    
    return NO;
}

/************************************ COPY ************************************/

- (void)copyFile:(id)sender
{
    [self copyFileFiles];
}

- (void)copyFiles:(id)sender
{
    [self copyFileFiles];
}

- (void)copyFileFiles
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSMutableArray *items = [[NSMutableArray alloc] init];
    
    // key : it.twsweb.Crypto-Cloud.CCMetadata      Value : (NSData) metadata
    
    if (_isSelectedMode) {
        
        NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];

        for (CCMetadata *metadata in selectedMetadatas) {
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]]) {
                
                NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:[NSKeyedArchiver archivedDataWithRootObject:metadata], @"it.twsweb.Crypto-Cloud.CCMetadata",nil];
                [items addObject:item];
            }
        }
        
        [self tableViewSelect:NO];
        
    } else {
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser,_metadata.fileID]]) {
            
            NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:[NSKeyedArchiver archivedDataWithRootObject:_metadata], @"it.twsweb.Crypto-Cloud.CCMetadata", nil];
            [items addObject:item];
        }
    }
    
    pasteboard.items = items;
}

/************************************ PASTE ************************************/

- (void)pasteFile:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [self uploadFilePasteArray:[pasteboard items] cryptated:NO];
}

- (void)pasteFileEncrypted:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [self uploadFilePasteArray:[pasteboard items] cryptated:YES];
}

- (void)pasteFiles:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [self uploadFilePasteArray:[pasteboard items] cryptated:NO];
}

- (void)pasteFilesEncrypted:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [self uploadFilePasteArray:[pasteboard items] cryptated:YES];
}

- (void)uploadFilePasteArray:(NSArray *)items cryptated:(BOOL)cryptated
{
    for (NSDictionary *dic in items) {
        
        // key   : it.twsweb.Crypto-Cloud.CCMetadata
        // Value : (NSData) metadata
        
        NSData *dataMetadata = [dic objectForKey:@"it.twsweb.Crypto-Cloud.CCMetadata"];
        CCMetadata *metadata = [NSKeyedUnarchiver unarchiveObjectWithData:dataMetadata];
            
        TableAccount *account = [CCCoreData getTableAccountFromAccount:metadata.account];
        NSString *directoryUser = [CCUtility getDirectoryActiveUser:account.user activeUrl:account.url];
            
        if (directoryUser) {
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, metadata.fileID]]) {
                
                [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, metadata.fileID] toPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileNamePrint]];
            
                [[CCNetworking sharedNetworking] uploadFile:metadata.fileNamePrint serverUrl:_localServerUrl cryptated:cryptated onlyPlist:NO session:upload_session taskStatus:taskStatusResume selector:nil selectorPost:nil parentRev:nil errorCode:0 delegate:nil];
            }
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Lock Passcode =====
#pragma --------------------------------------------------------------------------------------------

- (NSUInteger)passcodeViewControllerNumberOfFailedAttempts:(CCBKPasscode *)aViewController
{
    return _failedAttempts;
}

- (NSDate *)passcodeViewControllerLockUntilDate:(CCBKPasscode *)aViewController
{
    return _lockUntilDate;
}

- (void)passcodeViewCloseButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if (aViewController.fromType == CCBKPasscodeFromLockScreen || aViewController.fromType == CCBKPasscodeFromLockDirectory || aViewController.fromType == CCBKPasscodeFromDisactivateDirectory ) {
        if ([aPasscode isEqualToString:[CCUtility getBlockCode]]) {
            _lockUntilDate = nil;
            _failedAttempts = 0;
            aResultHandler(YES);
        } else aResultHandler(NO);
    } else aResultHandler(YES);
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    [aViewController dismissViewControllerAnimated:YES completion:nil];
    
    switch (aViewController.type) {
            
        case BKPasscodeViewControllerCheckPasscodeType: {
            
            if (aViewController.fromType == CCBKPasscodeFromPasscode) {
                
                CCCrypto *crypto = [[CCCrypto alloc] init];
                
                // verifichiamo se il passcode è corretto per il seguente file -> UUID
                if ([crypto verifyPasscode:aPasscode uuid:_metadata.uuid text:_metadata.title]) {
                    
                    // scriviamo il passcode
                    [CCUtility setKeyChainPasscodeForUUID:_metadata.uuid conPasscode:aPasscode];
                    
                    [self readFolderWithForced:YES];
                    
                } else {
                    
                    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_error_passcode_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                    [alertView show];
                }
            }
            
            if (aViewController.fromType == CCBKPasscodeFromLockDirectory) {
                
                // possiamo procedere alla prossima directory
                [self performSegueDirectoryWithControlPasscode:false];
                
                // avviamo la sessione Passcode Lock con now
                app.sessionePasscodeLock = [NSDate date];
            }
            
            // disattivazione lock cartella
            if (aViewController.fromType == CCBKPasscodeFromDisactivateDirectory) {
                
                NSString *lockServerUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:_metadata.fileNameData];
                
                if ([CCCoreData setDirectoryUnLock:lockServerUrl activeAccount:app.activeAccount] == NO) {
                    
                    [app messageNotification:@"_error_" description:@"_error_operation_canc_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
                }
                
                [self.tableView reloadData];
            }
        }
            break;
        default:
            break;
    }
}

- (void)comandoLockPassword
{
    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:_metadata.fileNameData];

    // se non è abilitato il Lock Passcode esci
    if ([[CCUtility getBlockCode] length] == 0) {
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_warning_", nil) message:NSLocalizedString(@"_only_lock_passcode_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
        return;
    }
    
    // se è richiesta la disattivazione si chiede la password
    if ([CCCoreData isDirectoryLock:lockServerUrl activeAccount:app.activeAccount]) {
        
        CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
        viewController.delegate = self;
        viewController.fromType = CCBKPasscodeFromDisactivateDirectory;
        viewController.type = BKPasscodeViewControllerCheckPasscodeType;
        viewController.inputViewTitlePassword = YES;
        
        if ([CCUtility getSimplyBlockCode]) {
            
            viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 6;
            
        } else {
            
            viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 64;
        }
        
        BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:BKPasscodeKeychainServiceName];
        touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
        viewController.touchIDManager = touchIDManager;

        viewController.title = NSLocalizedString(@"_passcode_protection_", nil);
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_ENCRYPTED;
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [self presentViewController:navigationController animated:YES completion:nil];
        
        return;
    }
    
    // ---------------- ACTIVATE PASSWORD
    
    if([CCCoreData setDirectoryLock:lockServerUrl activeAccount:app.activeAccount]) {
        
        NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:_metadata.fileID];
        if (indexPath) [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];

        
    } else {
        
        [app messageNotification:@"_error_" description:@"_error_operation_canc_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Swipe Tablet -> menu =====
#pragma --------------------------------------------------------------------------------------------

// more
- (NSString *)tableView:(UITableView *)tableView titleForSwipeAccessoryButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NSLocalizedString(@"_more_", nil);
}

+ (UIView *)headerActionSheet:(UITableViewController *)vc image:(UIImage *)image title:(NSString *)title cryptated:(BOOL)cryptated
{
    CGFloat width = CGRectGetWidth(vc.view.bounds);
    //CGFloat height = CGRectGetHeight(vc.view.bounds);
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 60)];
    headerView.backgroundColor = COLOR_NAVBAR_IOS7;
    
    // IMAGE
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectMake(13, 15, 30, 30);
    
    [headerView addSubview:imageView];
    
    // LABEL
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(55, 0, width-55-10, 60)];
    label.numberOfLines = 0;
    label.text = title;
    
    if (cryptated) label.textColor = COLOR_ENCRYPTED;
    else label.textColor = COLOR_CLEAR;
    
    label.font = [UIFont systemFontOfSize:13];
    label.backgroundColor = [UIColor clearColor];
    
    [headerView addSubview:label];
    
    return  headerView;
}

- (void)tableView:(UITableView *)tableView swipeAccessoryButtonPushedForRowAtIndexPath:(NSIndexPath *)indexPath
{
    _metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    NSString *titoloCriptaDecripta, *titoloPreferiti, *titoloLock, *titoloSynchronized;
    BOOL synchronized = NO;
    
    if (_metadata.cryptated) titoloCriptaDecripta = [NSString stringWithFormat:NSLocalizedString(@"_decrypt_", nil)];
    else titoloCriptaDecripta = [NSString stringWithFormat:NSLocalizedString(@"_encrypt_", nil)];
    
    if ([CCCoreData isFavorite:_metadata.fileID activeAccount:app.activeAccount]) titoloPreferiti = [NSString stringWithFormat:NSLocalizedString(@"_remove_favorites_", nil)];
    else titoloPreferiti = [NSString stringWithFormat:NSLocalizedString(@"_add_favorites_", nil)];
    
    NSString *synchronizedServerUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:_metadata.fileNameData];
    if (_metadata.directory && [CCCoreData isSynchronizedDirectory:synchronizedServerUrl activeAccount:app.activeAccount]) {
        
        titoloSynchronized = [NSString stringWithFormat:NSLocalizedString(@"_remove_synchronized_folder_", nil)];
        synchronized = YES;
        
    } else titoloSynchronized = [NSString stringWithFormat:NSLocalizedString(@"_synchronized_folder_", nil)];
    
    if (_metadata.directory) {
        // calcolo lockServerUrl
        NSString *lockServerUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:_metadata.fileNameData];
        
        if ([CCCoreData isDirectoryLock:lockServerUrl activeAccount:app.activeAccount]) titoloLock = [NSString stringWithFormat:NSLocalizedString(@"_remove_passcode_", nil)];
        else titoloLock = [NSString stringWithFormat:NSLocalizedString(@"_protect_passcode_", nil)];
    }
    
    /******************************************* DIRECTORY *******************************************/
    
    if (_metadata.directory) {
        
        UIImage *iconHeader;
        BOOL lockDirectory = NO;
        
        // calcolo lockServerUrl
        NSString *lockServerUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:_metadata.fileNameData];
        // Directory bloccata ?
        if ([CCCoreData isDirectoryLock:lockServerUrl activeAccount:app.activeAccount] && [[CCUtility getBlockCode] length] && app.sessionePasscodeLock == nil) lockDirectory = YES;
        
        AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.view title:nil];
        
        actionSheet.animationDuration = 0.2;
        actionSheet.cancelOnTapEmptyAreaEnabled = @(YES);
        actionSheet.automaticallyTintButtonImages = @(NO);

        actionSheet.blurRadius = 0.0f;
        actionSheet.blurTintColor = [UIColor colorWithWhite:0.0f alpha:0.50f];
        
        actionSheet.buttonHeight = 50.0;
        actionSheet.cancelButtonHeight = 50.0f;
        actionSheet.separatorHeight = 30.0f;
        
        actionSheet.selectedBackgroundColor = COLOR_SELECT_BACKGROUND;
        
        actionSheet.encryptedButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:14], NSForegroundColorAttributeName:COLOR_ENCRYPTED };
        actionSheet.buttonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:14], NSForegroundColorAttributeName:COLOR_GRAY };
        actionSheet.cancelButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:COLOR_BRAND };

        actionSheet.separatorColor = COLOR_SEPARATOR_TABLE;
        actionSheet.cancelButtonTitle = NSLocalizedString(@"_cancel_",nil);

        iconHeader = [UIImage imageNamed:_metadata.iconName];
        
        UIView *headerView = [[self class] headerActionSheet:self image:iconHeader title:_metadata.fileNamePrint cryptated:_metadata.cryptated];
        
        actionSheet.headerView = headerView;

        NSString *cameraUploadFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount];
        NSString *cameraUploadFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
        
        if (!([_metadata.fileName isEqualToString:cameraUploadFolderName] == YES && [_localServerUrl isEqualToString:cameraUploadFolderPath] == YES) && !lockDirectory) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_rename_", nil)
                                      image:[UIImage imageNamed:image_actionSheetRename]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                   
                                        // close swipe
                                        [self setEditing:NO animated:YES];
                                        
                                        //chiediamo il nome del file
                                        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_rename_",nil) message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"_cancel_",nil) otherButtonTitles:NSLocalizedString(@"_save_", nil), nil];
                                        [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
                                        alertView.tag = alertRename;
                                        UITextField *textField = [alertView textFieldAtIndex:0];
                                        textField.text = _metadata.fileNamePrint;
                                        [alertView show];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:cameraUploadFolderName] == YES && [_localServerUrl isEqualToString:cameraUploadFolderPath] == YES) && !lockDirectory) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_move_", nil)
                                      image:[UIImage imageNamed:image_actionSheetMove]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        // close swipe
                                        [self setEditing:NO animated:YES];
                                        
                                        [self moveOpenWindow:[[NSArray alloc] initWithObjects:indexPath, nil]];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:cameraUploadFolderName] == YES && [_localServerUrl isEqualToString:cameraUploadFolderPath] == YES) && !lockDirectory) {
            
            [actionSheet addButtonWithTitle:titoloCriptaDecripta
                                      image:[UIImage imageNamed:image_actionSheetCrypto]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeEncrypted
                                    handler:^(AHKActionSheet *as) {
                                        
                                        // close swipe
                                        [self setEditing:NO animated:YES];
                                        
                                        [self performSelector:@selector(encyptedDecryptedFolder) withObject:nil afterDelay:0.1];
                                    }];
        }

        if (!([_metadata.fileName isEqualToString:cameraUploadFolderName] == YES && [_localServerUrl isEqualToString:cameraUploadFolderPath] == YES)) {
            
            [actionSheet addButtonWithTitle:titoloLock
                                      image:[UIImage imageNamed:image_actionSheetLock]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeEncrypted
                                    handler:^(AHKActionSheet *as) {
                                        
                                        // close swipe
                                        [self setEditing:NO animated:YES];
                                        
                                        [self performSelector:@selector(comandoLockPassword) withObject:nil afterDelay:0.1];
                                    }];
        }
        
        if (_metadata.cryptated == NO && app.hasServerShareSupport && !lockDirectory) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_share_", nil)
                                      image:[UIImage imageNamed:image_actionSheetShare]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        // close swipe
                                        [self setEditing:NO animated:YES];
                                        
                                        [self openWindowShare:_metadata serverUrl:_localServerUrl];
                                    }];
        }
        
        
        if (!lockDirectory) {
        
            [actionSheet addButtonWithTitle:titoloSynchronized
                                      image:[UIImage imageNamed:image_actionSheetSynchronized]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        // close swipe
                                        [self setEditing:NO animated:YES];
                                        
                                        if (synchronized == NO) {
                                            
                                            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"",nil) message:NSLocalizedString(@"_synchronized_confirm_",nil) delegate:self cancelButtonTitle:NSLocalizedString(@"_cancel_",nil) otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                                            alertView.tag = alertSynchronization;
                                            [alertView show];
                                            
                                        } else {
                                            
                                            [[CCSynchronization sharedSynchronization] synchronizationFolder:[CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:_metadata.fileNameData]];
                                            [self performSelector:@selector(getDataSourceWithReloadTableView) withObject:nil afterDelay:0.5];
                                        }
                                    }];
        }
        
        [actionSheet show];
    }
    
    /******************************************* FILE *******************************************/
    
    if ([_metadata.type isEqualToString:metadataType_file] && !_metadata.directory) {
        
        UIImage *iconHeader;
        
        AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.view title:nil];
        
        actionSheet.animationDuration = 0.2;
        actionSheet.cancelOnTapEmptyAreaEnabled = @(YES);
        actionSheet.automaticallyTintButtonImages = @(NO);
        
        actionSheet.blurRadius = 0.0f;
        actionSheet.blurTintColor = [UIColor colorWithWhite:0.0f alpha:0.50f];
        
        actionSheet.buttonHeight = 50.0;
        actionSheet.cancelButtonHeight = 50.0f;
        actionSheet.separatorHeight = 30.0f;
        
        actionSheet.selectedBackgroundColor = COLOR_SELECT_BACKGROUND;
        
        actionSheet.encryptedButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:14], NSForegroundColorAttributeName:COLOR_ENCRYPTED };
        actionSheet.buttonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:14], NSForegroundColorAttributeName:COLOR_GRAY };
        actionSheet.cancelButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:COLOR_BRAND };
        
        actionSheet.separatorColor = COLOR_SEPARATOR_TABLE;
        actionSheet.cancelButtonTitle = NSLocalizedString(@"_cancel_",nil);
        
        // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, _metadata.fileID]])
            iconHeader = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, _metadata.fileID]];
        else
            iconHeader = [UIImage imageNamed:_metadata.iconName];
    
        UIView *headerView = [[self class] headerActionSheet:self image:iconHeader title:_metadata.fileNamePrint cryptated:_metadata.cryptated];
        actionSheet.headerView = headerView;

        [actionSheet addButtonWithTitle:NSLocalizedString(@"_rename_", nil)
                                  image:[UIImage imageNamed:image_actionSheetRename]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    //chiediamo il nome del file
                                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_rename_",nil) message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"_cancel_",nil) otherButtonTitles:NSLocalizedString(@"_save_", nil), nil];
                                    [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
                                    alertView.tag = alertRename;
                                    UITextField *textField = [alertView textFieldAtIndex:0];
                                    textField.text = _metadata.fileNamePrint;
                                    [alertView show];
                                }];
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_move_", nil)
                                  image:[UIImage imageNamed:image_actionSheetMove]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    [self moveOpenWindow:[[NSArray alloc] initWithObjects:indexPath, nil]];
                                }];
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_reload_", nil)
                                  image:[UIImage imageNamed:image_actionSheetReload]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    [self performSelector:@selector(reloadFile:) withObject:_metadata afterDelay:0.1];
                                }];
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_open_in_", nil)
                                  image:[UIImage imageNamed:image_actionSheetOpenIn]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    [self performSelector:@selector(openIn:) withObject:_metadata afterDelay:0.1];
                                }];

        if (_metadata.cryptated == NO && app.hasServerShareSupport) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_share_", nil)
                                      image:[UIImage imageNamed:image_actionSheetShare]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        // close swipe
                                        [self setEditing:NO animated:YES];
                                        
                                        [self openWindowShare:_metadata serverUrl:_localServerUrl];
                                    }];
        }

        [actionSheet addButtonWithTitle:titoloCriptaDecripta
                                  image:[UIImage imageNamed:image_actionSheetCrypto]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeEncrypted
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    [self performSelector:@selector(cmdEncryptedDecryptedFile) withObject:nil afterDelay:0.1];
                                }];
        
        [actionSheet addButtonWithTitle:titoloPreferiti
                                  image:[UIImage imageNamed:image_actionSheetFavorite]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    if ([CCCoreData isFavorite:_metadata.fileID activeAccount:app.activeAccount])
                                        [self removeFavorite:_metadata];
                                    else
                                        [self addFavorite:_metadata];
                                }];


        [actionSheet addButtonWithTitle:NSLocalizedString(@"_add_local_", nil)
                                  image:[UIImage imageNamed:image_actionSheetLocal]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    [self performSelector:@selector(addLocal:) withObject:_metadata afterDelay:0.1];
                                }];
        
        [actionSheet show];
    }
    
    /******************************************* TEMPLATE *******************************************/
    
    if ([_metadata.type isEqualToString:metadataType_model]) {
        
        UIImage *iconHeader;
     
        AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.view title:nil];
     
        actionSheet.animationDuration = 0.2;
        actionSheet.cancelOnTapEmptyAreaEnabled = @(YES);
        actionSheet.automaticallyTintButtonImages = @(NO);
        
        actionSheet.blurRadius = 0.0f;
        actionSheet.blurTintColor = [UIColor colorWithWhite:0.0f alpha:0.50f];
        
        actionSheet.buttonHeight = 50.0;
        actionSheet.cancelButtonHeight = 50.0f;
        actionSheet.separatorHeight = 30.0f;
        
        actionSheet.selectedBackgroundColor = COLOR_SELECT_BACKGROUND;
        
        actionSheet.encryptedButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:14], NSForegroundColorAttributeName:COLOR_ENCRYPTED };
        actionSheet.buttonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:14], NSForegroundColorAttributeName:COLOR_GRAY };
        actionSheet.cancelButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:COLOR_BRAND };
        
        actionSheet.separatorColor = COLOR_SEPARATOR_TABLE;
        actionSheet.cancelButtonTitle = NSLocalizedString(@"_cancel_",nil);

        iconHeader = [UIImage imageNamed:_metadata.iconName];
     
        UIView *headerView = [[self class] headerActionSheet:self image:iconHeader title:_metadata.fileNamePrint cryptated:_metadata.cryptated];
        actionSheet.headerView = headerView;
        
        if ([_metadata.model isEqualToString:@"note"]) {
        
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_rename_", nil)
                                      image:[UIImage imageNamed:image_actionSheetRename]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                    
                                        // close swipe
                                        [self setEditing:NO animated:YES];
                                        
                                        //chiediamo il nome del file
                                        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_rename_",nil) message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"_cancel_",nil) otherButtonTitles:NSLocalizedString(@"_save_", nil), nil];
                                        [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
                                        alertView.tag = alertRename;
                                        UITextField *textField = [alertView textFieldAtIndex:0];
                                        textField.text = _metadata.fileNamePrint;
                                        [alertView show];
                                }];
        }
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_move_", nil)
                                  image:[UIImage imageNamed:image_actionSheetMove]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    [self moveOpenWindow:[[NSArray alloc] initWithObjects:indexPath, nil]];
                                }];

        [actionSheet addButtonWithTitle:titoloPreferiti
                                  image:[UIImage imageNamed:image_actionSheetFavorite]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    if ([CCCoreData isFavorite:_metadata.fileID activeAccount:app.activeAccount])
                                        [self removeFavorite:_metadata];
                                    else
                                        [self addFavorite:_metadata];
                                }];

        [actionSheet addButtonWithTitle:NSLocalizedString(@"_add_local_", nil)
                                  image:[UIImage imageNamed:image_actionSheetLocal]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    // close swipe
                                    [self setEditing:NO animated:YES];
                                    
                                    [self performSelector:@selector(addLocal:) withObject:_metadata afterDelay:0.1];
                                }];

        [actionSheet show];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NSLocalizedString(@"_delete_", nil);
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    CCMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (metadata == nil || metadata.errorPasscode || (metadata.cryptated && [metadata.title length] == 0) || metadata.sessionTaskIdentifier  >= 0 || metadata.sessionTaskIdentifier >= 0) return NO;
    else return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    _metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (_metadata.errorPasscode || (_metadata.cryptated && [_metadata.title length] == 0) || _metadata.sessionTaskIdentifier >= 0 || _metadata.sessionTaskIdentifier >= 0) return UITableViewCellEditingStyleNone;
    else return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL lockDirectory = NO;
    
    // Directory locked ?
    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:_metadata.fileNameData];
    if ([CCCoreData isDirectoryLock:lockServerUrl activeAccount:app.activeAccount] && [[CCUtility getBlockCode] length] && app.sessionePasscodeLock == nil) lockDirectory = YES;
    
    if (lockDirectory && editingStyle == UITableViewCellEditingStyleDelete) {
        
        [app messageNotification:@"_error_" description:@"_folder_blocked_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
        
        return;
    }

    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        _metadata = [self getMetadataFromSectionDataSource:indexPath];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil)
                                                             style:UIAlertActionStyleDestructive
                                                           handler:^(UIAlertAction *action) {
                                                               [self performSelector:@selector(deleteFile) withObject:nil afterDelay:0.1];
                                                           }]];
        
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil)
                                                             style:UIAlertActionStyleCancel
                                                           handler:^(UIAlertAction *action) {
                                                               [alertController dismissViewControllerAnimated:YES completion:nil];
                                                           }]];
                
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            [alertController.view layoutIfNeeded];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)clearDateReadDataSource:(NSNotification *)notification
{
    _dateReadDataSource = Nil;
}

- (void)getDataSourceWithReloadTableView
{
    [self getDataSourceWithReloadTableView:_localDirectoryID fileID:nil selector:nil];
}

- (void)getDataSourceWithReloadTableView:(NSString *)directoryID fileID:(NSString *)fileID selector:(NSString *)selector
{
    if (app.activeAccount == nil || app.activeUrl == nil || directoryID == nil)
        return;
    
    // Reload -> Favorite ?
    if (fileID)
        if ([CCCoreData isFavorite:fileID activeAccount:app.activeAccount])
            [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadTableFavorite" object:nil];

    // Reload -> Self se non siamo nella dir appropriata cercala e se è in memoria reindirizza il reload
    if ([directoryID isEqualToString:_localDirectoryID] == NO || _localServerUrl == nil) {
        
        if ([selector isEqualToString:selectorDownloadSynchronized]) {
            [app.controlCenter reloadDatasource];
        } else {
            CCMain *main = [app.listMainVC objectForKey:[CCCoreData getServerUrlFromDirectoryID:directoryID activeAccount:app.activeAccount]];
            if (main) {
                [main getDataSourceWithReloadTableView];
            } else {
                [self tableViewReload];
                [app.controlCenter reloadDatasource];
            }
        }
        
        return;
    }
    
    [app.controlCenter reloadDatasource];
    
    // Settaggio variabili per le ottimizzazioni
    _directoryGroupBy = [CCUtility getGroupBySettings];
    _directoryOrder = [CCUtility getOrderSettings];
    
    // Controllo data lettura Data Source
    NSDate *dateDateRecordDirectory = [CCCoreData getDateReadDirectoryID:_localDirectoryID activeAccount:app.activeAccount];
    
    if ([dateDateRecordDirectory compare:_dateReadDataSource] == NSOrderedDescending || dateDateRecordDirectory == nil || _dateReadDataSource == nil) {
        
        NSLog(@"[LOG] Rebuild Data Source File : %@", _localServerUrl);

        _dateReadDataSource = [NSDate date];
    
        // Data Source
    
        NSArray *recordsTableMetadata = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", app.activeAccount, directoryID] fieldOrder:[CCUtility getOrderSettings] ascending:[CCUtility getAscendingSettings]];
    
        _sectionDataSource = [CCSection creataDataSourseSectionTableMetadata:recordsTableMetadata listProgressMetadata:nil groupByField:_directoryGroupBy replaceDateToExifDate:NO activeAccount:app.activeAccount];
    
        // if DataSource has no records, Data Nil
        //if ([_sectionDataSource.allRecordsDataSource count] == 0)
        //    _dateReadDataSource = nil;
        
    } else {
        
         NSLog(@"[LOG] [OPTIMIZATION] Rebuild Data Source File : %@ - %@", _localServerUrl, _dateReadDataSource);
    }
    
    [self tableViewReload];
    
    [self setTitleBackgroundTableView];
    
    [app updateApplicationIconBadgeNumber];
}

- (NSArray *)getMetadatasFromSelectedRows:(NSArray *)selectedRows
{
    NSMutableArray *metadatas = [[NSMutableArray alloc] init];
    
    if (selectedRows.count > 0) {
    
        for (NSIndexPath *selectionIndex in selectedRows) {
            
            NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:selectionIndex.section]] objectAtIndex:selectionIndex.row];
            CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];

            [metadatas addObject:metadata];
        }
    }
    
    return metadatas;
}

- (CCMetadata *)getMetadataFromSectionDataSource:(NSIndexPath *)indexPath
{
    NSInteger section = indexPath.section + 1;
    NSInteger row = indexPath.row + 1;
    
    NSInteger totSections =[_sectionDataSource.sections count] ;
    
    if ((totSections < section) || (section > totSections)) {
      
        NSString *message = [NSString stringWithFormat:@"DEBUG [0] : error section, totSections = %lu - section = %lu", (long)totSections, (long)section];
        NSLog(@"[LOG] %@", message);
#if DEBUG
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
#endif
        return nil;
    }
    
    id valueSection = [_sectionDataSource.sections objectAtIndex:indexPath.section];
    
    NSArray *fileIDs = [_sectionDataSource.sectionArrayRow objectForKey:valueSection];
    
    if (fileIDs) {
        
        NSInteger totRows =[fileIDs count] ;
        
        if ((totRows < row) || (row > totRows)) {
            
            NSString *message = [NSString stringWithFormat:@"DEBUG [1] : error row, totRows = %lu - row = %lu [%@] [%@] [%@]", (long)totRows, (long)row, valueSection, _localDirectoryID, _localServerUrl];
            NSLog(@"[LOG] %@", message);
#if DEBUG
            UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
            [alertView show];
#endif
            return nil;
        }

    } else {
        
        NSLog(@"[LOG] DEBUG [2] : fileIDs is NIL");
#if DEBUG
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:@"DEBUG [2] : fileIDs is NIL" delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
#endif

        return nil;
    }
    
    NSString *fileID = [fileIDs objectAtIndex:indexPath.row];
    
    return [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
}

- (NSArray *)getMetadatasFromSectionDataSource:(NSInteger)section
{
    NSInteger totSections =[_sectionDataSource.sections count] ;
    
    if ((totSections < (section + 1)) || ((section + 1) > totSections)) {
        
#if DEBUG
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:[NSString stringWithFormat:@"DEBUG [3] : error section, totSections = %lu - section = %lu", (long)totSections, (long)section] delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
#endif
        return nil;
    }
    
    id valueSection = [_sectionDataSource.sections objectAtIndex:section];
    
    return  [_sectionDataSource.sectionArrayRow objectForKey:valueSection];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Table ==== 
#pragma --------------------------------------------------------------------------------------------

- (void)tableViewSelect:(BOOL)edit
{
    // chiudiamo eventuali swipe aperti
    if (edit) [self.tableView setEditing:NO animated:NO];
    
    [self.tableView setAllowsMultipleSelectionDuringEditing:edit];
    [self.tableView setEditing:edit animated:YES];
    _isSelectedMode = edit;
    
    if (edit)
        [self setUINavigationBarSeleziona];
    else
        [self setUINavigationBarDefault];
    
    [self setTitleNOAnimation];
}

- (void)tableViewReload
{
    // ricordiamoci le row selezionate
    NSArray *indexPaths = [self.tableView indexPathsForSelectedRows];
    [self.tableView reloadData];
    
    for (NSIndexPath *path in indexPaths)
        [self.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    
    [self setTableViewFooter];
    
    if (self.tableView.editing)
        [self setTitleNOAnimation];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[_sectionDataSource.sectionArrayRow allKeys] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:section]] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSArray *sections = [_sectionDataSource.sectionArrayRow allKeys];
    NSString *sectionTitle = [sections objectAtIndex:section];
    
    if ([sectionTitle isKindOfClass:[NSString class]] && [sectionTitle rangeOfString:@"download"].location != NSNotFound) return 18.f;
    if ([sectionTitle isKindOfClass:[NSString class]] && [sectionTitle rangeOfString:@"upload"].location != NSNotFound) return 18.f;
    
    if ([_directoryGroupBy isEqualToString:@"none"] && [sections count] <= 1) return 0.f;
    
    return 20.f;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    float shift;
    UIVisualEffectView *visualEffectView;
    
    // Titolo
    NSString *titleSection;
    
    // Controllo
    if ([_sectionDataSource.sections count] == 0)
        return nil;
    
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]]) titleSection = [_sectionDataSource.sections objectAtIndex:section];
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSDate class]]) titleSection = [CCUtility getTitleSectionDate:[_sectionDataSource.sections objectAtIndex:section]];
    
    if ([titleSection isEqualToString:@"_none_"]) titleSection = @"";
    else if ([titleSection rangeOfString:@"download"].location != NSNotFound) titleSection = NSLocalizedString(@"_title_section_download_",nil);
    else if ([titleSection rangeOfString:@"upload"].location != NSNotFound) titleSection = NSLocalizedString(@"_title_section_upload_",nil);
    else titleSection = NSLocalizedString(titleSection,nil);
    
    // Formato titolo
    NSString *currentDevice = [CCUtility currentDevice];
    if ([currentDevice rangeOfString:@"iPad3"].location != NSNotFound) {
        
        visualEffectView = [[UIVisualEffectView alloc] init];
        visualEffectView.backgroundColor = COLOR_GROUPBY_BAR_NO_BLUR;
        
    } else {
        
        UIVisualEffect *blurEffect;
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        visualEffectView.backgroundColor = COLOR_GROUPBY_BAR;
    }
    
    if ([_directoryGroupBy isEqualToString:@"alphabetic"]) {
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) shift = - 35;
        else shift =  - 20;
        
    } else shift = - 10;
    
    // Title
    UILabel *titleLabel=[[UILabel alloc]initWithFrame:CGRectMake(10, -12, 0, 44)];
    titleLabel.backgroundColor=[UIColor clearColor];
    titleLabel.textColor = COLOR_GRAY;
    titleLabel.font = [UIFont systemFontOfSize:12];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.text = titleSection;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    [visualEffectView addSubview:titleLabel];
    
    // Elements
    UILabel *elementLabel=[[UILabel alloc]initWithFrame:CGRectMake(shift, -12, 0, 44)];
    elementLabel.backgroundColor=[UIColor clearColor];
    elementLabel.textColor = COLOR_GRAY;
    elementLabel.font = [UIFont systemFontOfSize:12];
    elementLabel.textAlignment = NSTextAlignmentRight;
    elementLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    NSArray *metadatas = [self getMetadatasFromSectionDataSource:section];
    NSUInteger rowsCount = [metadatas count];
    
    if (rowsCount == 0) return nil;
    if (rowsCount == 1) elementLabel.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)rowsCount,  NSLocalizedString(@"_element_",nil)];
    if (rowsCount > 1) elementLabel.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)rowsCount,  NSLocalizedString(@"_elements_",nil)];
    
    [visualEffectView addSubview:elementLabel];
    
    return visualEffectView;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [_sectionDataSource.sections indexOfObject:title];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if ([_directoryGroupBy isEqualToString:@"alphabetic"])
        return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
    else
        return nil;
}

/*
-(void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([indexPath row] == ((NSIndexPath*)[[tableView indexPathsForVisibleRows] lastObject]).row){
        
    }
}
*/

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *typeCell;
    NSString *dataFile;
    NSString *lunghezzaFile;
    
    CCMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if ([metadata.session isEqualToString:@""] || metadata.session == nil) typeCell = @"CellMain";
    else typeCell = @"CellMainTransfer";
    
    if (!metadata)
        return [tableView dequeueReusableCellWithIdentifier:typeCell];
    
    CCCellMainTransfer *cell = (CCCellMainTransfer *)[tableView dequeueReusableCellWithIdentifier:typeCell forIndexPath:indexPath];
    
    // separator
    cell.separatorInset = UIEdgeInsetsMake(0.f, 60.f, 0.f, 0.f);
    
    // change color selection
    UIView *selectionColor = [[UIView alloc] init];
    selectionColor.backgroundColor = COLOR_SELECT_BACKGROUND;
    cell.selectedBackgroundView = selectionColor;
    
    if ([typeCell isEqualToString:@"CellMain"]) cell.backgroundColor = [UIColor whiteColor];
    if ([typeCell isEqualToString:@"CellMainTransfer"]) cell.backgroundColor = COLOR_TRANSFER_BACKGROUND;
    
    // ----------------------------------------------------------------------------------------------------------
    // DEFAULT
    // ----------------------------------------------------------------------------------------------------------
    
    cell.fileImageView.image = nil;
    cell.statusImageView.image = nil;
    cell.favoriteImageView.image = nil;
    cell.synchronizedImageView.image = nil;
    cell.sharedImageView.image = nil;
    
    cell.labelTitle.enabled = YES;
    cell.labelTitle.text = @"";
    cell.labelInfoFile.enabled = YES;
    cell.labelInfoFile.text = @"";
    
    cell.progressView.progress = 0.0;
    cell.progressView.hidden = YES;
    
    cell.cancelTaskButton.hidden = YES;
    cell.reloadTaskButton.hidden = YES;
    cell.stopTaskButton.hidden = YES;
    
    // colori e font
    if (metadata.cryptated) {
        cell.labelTitle.textColor = COLOR_ENCRYPTED;
        //nameLabel.font = RalewayLight(13.0f);
        cell.labelInfoFile.textColor = [UIColor blackColor];
        //detailLabel.font = RalewayLight(9.0f);
    } else {
        cell.labelTitle.textColor = COLOR_CLEAR;
        //nameLabel.font = RalewayLight(13.0f);
        cell.labelInfoFile.textColor = [UIColor blackColor];
        //detailLabel.font = RalewayLight(9.0f);
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // File Name & Folder
    // ----------------------------------------------------------------------------------------------------------
    
    // nome del file
    cell.labelTitle.text = metadata.fileNamePrint;
    
    // è una directory
    if (metadata.directory) {
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.labelInfoFile.text = [CCUtility dateDiff:metadata.date];
        
        lunghezzaFile = @" ";
        
        // ----------------------------------------------------------------------------------------------------------
        // Synchronize
        // ----------------------------------------------------------------------------------------------------------
        
        NSString *synchronizedServerUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:metadata.fileNameData];
        if ([CCCoreData isSynchronizedDirectory:synchronizedServerUrl activeAccount:app.activeAccount]) {
            
            if ([[CCSynchronization sharedSynchronization] synchronizationAnimationDirectory:[[NSArray alloc] initWithObjects:synchronizedServerUrl, nil] callViewController:NO]) {
                
                NSURL *myURL;
                
                if (metadata.cryptated) myURL = [[NSBundle mainBundle] URLForResource: @"synchronizedcrypto" withExtension:@"gif"];
                else myURL = [[NSBundle mainBundle] URLForResource: @"synchronized" withExtension:@"gif"];
                
                cell.synchronizedImageView.image = [UIImage animatedImageWithAnimatedGIFURL:myURL];
                
            } else {
                
                if (metadata.cryptated) cell.synchronizedImageView.image = [UIImage imageNamed:image_synchronizedcrypto];
                else cell.synchronizedImageView.image = [UIImage imageNamed:image_synchronized];
            }
        }

    } else {
    
        // è un file
                
        dataFile = [CCUtility dateDiff:metadata.date];
        lunghezzaFile = [CCUtility transformedSize:metadata.size];
        
        // Plist ancora da scaricare
        if (metadata.cryptated && [metadata.title length] == 0) {
            
            dataFile = @" ";
            lunghezzaFile = @" ";
        }
        
        TableLocalFile *recordLocalFile = [CCCoreData getLocalFileWithFileID:metadata.fileID activeAccount:app.activeAccount];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        
        if ([metadata.type isEqualToString:metadataType_model] && [dataFile isEqualToString:@" "] == NO && [lunghezzaFile isEqualToString:@" "] == NO)
            cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", dataFile];
        
        if ([metadata.type isEqualToString:metadataType_file] && [dataFile isEqualToString:@" "] == NO && [lunghezzaFile isEqualToString:@" "] == NO) {            
            if (recordLocalFile && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]])
                cell.labelInfoFile.text = [NSString stringWithFormat:@"%@ • %@", dataFile, lunghezzaFile];
            else
                cell.labelInfoFile.text = [NSString stringWithFormat:@"%@ ◦ %@", dataFile, lunghezzaFile];
        }

        // Plist ancora da scaricare
        if ([dataFile isEqualToString:@" "] && [lunghezzaFile isEqualToString:@" "])
            cell.labelInfoFile.text = NSLocalizedString(@"_no_plist_pull_down_",nil);
    
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // File Image View
    // ----------------------------------------------------------------------------------------------------------

    // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]]) {
        
        cell.fileImageView.image = [app.icoImagesCache objectForKey:metadata.fileID];
        
        if (cell.fileImageView.image == nil) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                
                UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
                
                [app.icoImagesCache setObject:image forKey:metadata.fileID];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    CCCellMainTransfer *cell = [tableView cellForRowAtIndexPath:indexPath];
                    
                    if (cell)
                        cell.fileImageView.image = image;
                });
            });
        }

    } else {
        
        cell.fileImageView.image = [UIImage imageNamed:metadata.iconName];
        
        if (metadata.thumbnailExists)
            [self downloadThumbnail:metadata];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // Image Status cyptated & Lock Passcode
    // ----------------------------------------------------------------------------------------------------------
    
    // File Cyptated
    if (metadata.cryptated && metadata.directory == NO && [metadata.type isEqualToString:metadataType_model] == NO) {
     
        cell.statusImageView.image = [UIImage imageNamed:image_lock];
    }
    
    // Directory con passcode lock attivato
    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:metadata.fileNameData];
    if (metadata.directory && ([CCCoreData isDirectoryLock:lockServerUrl activeAccount:app.activeAccount] && [[CCUtility getBlockCode] length])) cell.statusImageView.image = [UIImage imageNamed:image_passcode];
    
    // ----------------------------------------------------------------------------------------------------------
    // Favorite
    // ----------------------------------------------------------------------------------------------------------

    if ([CCCoreData isFavorite:metadata.fileID activeAccount:app.activeAccount]) {
        
        if (metadata.cryptated) cell.favoriteImageView.image = [UIImage imageNamed:image_favoritecrypto];
        else cell.favoriteImageView.image = [UIImage imageNamed:image_favorite];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // Share
    // ----------------------------------------------------------------------------------------------------------

    NSString *shareLink = [app.sharesLink objectForKey:[_localServerUrl stringByAppendingString:metadata.fileName]];
    NSString *shareUserAndGroup = [app.sharesUserAndGroup objectForKey:[_localServerUrl stringByAppendingString:metadata.fileName]];
    BOOL isShare = ([metadata.permissions length] > 0) && ([metadata.permissions rangeOfString:k_permission_shared].location != NSNotFound) && ([_fatherPermission rangeOfString:k_permission_shared].location == NSNotFound);
    BOOL isMounted = ([metadata.permissions length] > 0) && ([metadata.permissions rangeOfString:k_permission_mounted].location != NSNotFound) && ([_fatherPermission rangeOfString:k_permission_mounted].location == NSNotFound);
    
    // Aggiungiamo il Tap per le shared
    if (isShare || [shareLink length] > 0 || [shareUserAndGroup length] > 0 || isMounted) {
    
        if (isShare) {
       
            cell.sharedImageView.image = [UIImage imageNamed:image_shareConnect];
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionConnectionMounted:)];
            [tap setNumberOfTapsRequired:1];
            cell.sharedImageView.userInteractionEnabled = YES;
            [cell.sharedImageView addGestureRecognizer:tap];
        }
        
        if (isMounted) {
            
            cell.sharedImageView.image = [UIImage imageNamed:image_shareMounted];
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionConnectionMounted:)];
            [tap setNumberOfTapsRequired:1];
            cell.sharedImageView.userInteractionEnabled = YES;
            [cell.sharedImageView addGestureRecognizer:tap];
        }
        
        if ([shareLink length] > 0 || [shareUserAndGroup length] > 0) {
        
            if ([shareLink length] > 0) cell.sharedImageView.image = [UIImage imageNamed:image_shareLink];
            if ([shareUserAndGroup length] > 0) cell.sharedImageView.image = [UIImage imageNamed:image_shareUser];
        
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionShared:)];
            [tap setNumberOfTapsRequired:1];
            cell.sharedImageView.userInteractionEnabled = YES;
            [cell.sharedImageView addGestureRecognizer:tap];
        }
        
    } else {
        
        cell.sharedImageView.userInteractionEnabled = NO;
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // downloadFile
    // ----------------------------------------------------------------------------------------------------------
    
    if ([metadata.session length] > 0 && [metadata.session rangeOfString:@"download"].location != NSNotFound) {
        
        if (metadata.cryptated) cell.statusImageView.image = [UIImage imageNamed:image_statusdownloadcrypto];
        else cell.statusImageView.image = [UIImage imageNamed:image_statusdownload];

        // sessionTaskIdentifier : RELOAD + STOP
        if (metadata.sessionTaskIdentifier != taskIdentifierDone) {
            
            if (metadata.cryptated)[cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptaskcrypto] forState:UIControlStateNormal];
            else [cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptask] forState:UIControlStateNormal];
            
            cell.cancelTaskButton.hidden = NO;

            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtaskcrypto] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtask] forState:UIControlStateNormal];
            
            cell.reloadTaskButton.hidden = NO;
            
        }
        
        // sessionTaskIdentifierPlist : RELOAD
        if (metadata.sessionTaskIdentifierPlist != taskIdentifierDone) {
            
            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtaskcrypto] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtask] forState:UIControlStateNormal];
            
            cell.reloadTaskButton.hidden = NO;
        }

        cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", lunghezzaFile];
        
        float progress = [[app.listProgressMetadata objectForKey:metadata.fileID] floatValue];
        if (progress > 0) {
            
            if (metadata.cryptated) cell.progressView.progressTintColor = COLOR_ENCRYPTED;
            else cell.progressView.progressTintColor = COLOR_CLEAR;
            
            cell.progressView.progress = progress;
            cell.progressView.hidden = NO;
        }

        // ----------------------------------------------------------------------------------------------------------
        // downloadFile Error
        // ----------------------------------------------------------------------------------------------------------
        
        if (metadata.sessionTaskIdentifier == taskIdentifierError || metadata.sessionTaskIdentifierPlist == taskIdentifierError) {
            
            cell.statusImageView.image = [UIImage imageNamed:image_statuserror];
            
            if ([metadata.sessionError length] == 0)
                cell.labelInfoFile.text = [NSString stringWithFormat:@"%@, %@", NSLocalizedString(@"_error_",nil), NSLocalizedString(@"_file_not_downloaded_",nil)];
            else
                cell.labelInfoFile.text = [CCError manageErrorKCF:[metadata.sessionError integerValue] withNumberError:NO];
        }
    }    
    
    // ----------------------------------------------------------------------------------------------------------
    // uploadFile
    // ----------------------------------------------------------------------------------------------------------
    
    if ([metadata.session length] > 0 && [metadata.session rangeOfString:@"upload"].location != NSNotFound) {
        
        if (metadata.cryptated) cell.statusImageView.image = [UIImage imageNamed:image_statusuploadcrypto];
        else cell.statusImageView.image = [UIImage imageNamed:image_statusupload];
        
        if (metadata.cryptated)[cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_removetaskcrypto] forState:UIControlStateNormal];
        else [cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_removetask] forState:UIControlStateNormal];
        cell.cancelTaskButton.hidden = NO;
        
        if (metadata.sessionTaskIdentifier == taskIdentifierStop) {
            
            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtaskcrypto] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtask] forState:UIControlStateNormal];
            
            if (metadata.cryptated) cell.statusImageView.image = [UIImage imageNamed:image_statusstopcrypto];
            else cell.statusImageView.image = [UIImage imageNamed:image_statusstop];
            
            cell.reloadTaskButton.hidden = NO;
            cell.stopTaskButton.hidden = YES;
            
        } else {
            
            if (metadata.cryptated)[cell.stopTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptaskcrypto] forState:UIControlStateNormal];
            else [cell.stopTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptask] forState:UIControlStateNormal];
            
            cell.stopTaskButton.hidden = NO;
            cell.reloadTaskButton.hidden = YES;
        }
        
        // se non c'è una preview in bianconero metti l'immagine di default
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]] == NO)
            cell.fileImageView.image = [UIImage imageNamed:image_uploaddisable];
        
        cell.labelTitle.enabled = NO;
        cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", lunghezzaFile];
        
        float progress = [[app.listProgressMetadata objectForKey:metadata.fileID] floatValue];
        if (progress > 0) {
            
            if (metadata.cryptated) cell.progressView.progressTintColor = COLOR_ENCRYPTED;
            else cell.progressView.progressTintColor = COLOR_CLEAR;
            
            cell.progressView.progress = progress;
            cell.progressView.hidden = NO;
        }
        
        // ----------------------------------------------------------------------------------------------------------
        // uploadFileError
        // ----------------------------------------------------------------------------------------------------------
    
        if (metadata.sessionTaskIdentifier == taskIdentifierError || metadata.sessionTaskIdentifierPlist == taskIdentifierError) {
        
            cell.labelTitle.enabled = NO;
            cell.statusImageView.image = [UIImage imageNamed:image_statuserror];
        
            if ([metadata.sessionError length] == 0)
                cell.labelInfoFile.text = [NSString stringWithFormat:@"%@, %@", NSLocalizedString(@"_error_",nil), NSLocalizedString(@"_file_not_uploaded_",nil)];
            else
                cell.labelInfoFile.text = [CCError manageErrorKCF:[metadata.sessionError integerValue] withNumberError:NO];
        }
    }

    [cell.reloadTaskButton addTarget:self action:@selector(reloadTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    [cell.cancelTaskButton addTarget:self action:@selector(cancelTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    [cell.stopTaskButton addTarget:self action:@selector(stopTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];

    return cell;
}

- (void)setTableViewFooter
{
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 40)];
    [footerView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    
    UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 40)];
    [footerLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    
    UIFont *appFont = [UIFont systemFontOfSize:12];
    
    footerLabel.font = appFont;
    footerLabel.textColor = [UIColor grayColor];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    
    NSString *folders;
    NSString *files;
    NSString *footerText;
    
    if (_sectionDataSource.directories > 1) {
        folders = [NSString stringWithFormat:@"%ld %@", (long)_sectionDataSource.directories, NSLocalizedString(@"_folders_", nil)];
    } else if (_sectionDataSource.directories == 1){
        folders = [NSString stringWithFormat:@"%ld %@", (long)_sectionDataSource.directories, NSLocalizedString(@"_folder_", nil)];
    } else {
        folders = @"";
    }
    
    if (_sectionDataSource.files > 1) {
        files = [NSString stringWithFormat:@"%ld %@ %@", (long)_sectionDataSource.files, NSLocalizedString(@"_files_", nil), [CCUtility transformedSize:_sectionDataSource.totalSize]];
    } else if (_sectionDataSource.files == 1){
        files = [NSString stringWithFormat:@"%ld %@ %@", (long)_sectionDataSource.files, NSLocalizedString(@"_file_", nil), [CCUtility transformedSize:_sectionDataSource.totalSize]];
    } else {
        files = @"";
    }
    
    if ([folders isEqualToString:@""]) {
        footerText = files;
    } else if ([files isEqualToString:@""]) {
        footerText = folders;
    } else {
        footerText = [NSString stringWithFormat:@"%@, %@", folders, files];
    }
    
    footerLabel.text = footerText;
    
    [footerView addSubview:footerLabel];
    [self.tableView setTableFooterView:footerView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *textMessage;
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    // se non può essere selezionata deseleziona
    if ([cell isEditing] == NO)
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // se siamo in modalità editing impostiamo il titolo dei selezioati e usciamo subito
    if (self.tableView.editing) {
        
        [self setTitleNOAnimation];
        return;
    }
    
    // test crash
    NSArray *metadatas = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]];
    if (indexPath.row >= [metadatas count]) return;
    
    // settiamo il record file.
    _metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    // se è in corso una sessione
    if ([_metadata.session length] > 0) return;
    
    if (_metadata.errorPasscode) {
            
        // se UUID è nil lo sta ancora caricando quindi esci
        if (!_metadata.uuid) return;
        
        // esiste un hint ??
        CCCrypto *crypto = [[CCCrypto alloc] init];
        NSString *hint = [crypto getHintFromFile:_metadata.fileName isLocal:NO directoryUser:app.directoryUser];
        
        // qui !! la richiesta della nuova passcode
        if ([_metadata.uuid isEqualToString:[CCUtility getUUID]]) {
            
            // stesso UUID ... la password è stata modificata !!!!!!
            
            if (hint) textMessage = [NSString stringWithFormat:NSLocalizedString(@"_same_device_different_passcode_hint_",nil), hint];
            else textMessage = NSLocalizedString(@"_same_device_different_passcode_", nil);
            
            UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:textMessage delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
            [alertView show];
                
        } else {
                
            // UUID diverso.
            
            if (hint) textMessage = [NSString stringWithFormat:NSLocalizedString(@"_file_encrypted_another_device_hint_",nil), _metadata.nameCurrentDevice, hint];
            else textMessage = [NSString stringWithFormat:NSLocalizedString(@"_file_encrypted_another_device_",nil), _metadata.nameCurrentDevice];
            
            UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:textMessage delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
            [alertView show];
        }
            
        // chiediamo la passcode e ricarichiamo tutto.
        CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
        viewController.delegate = self;
        viewController.fromType = CCBKPasscodeFromPasscode;
        viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
        viewController.passcodeInputView.maximumLength = 64;
        viewController.type = BKPasscodeViewControllerCheckPasscodeType;
        viewController.inputViewTitlePassword = NO;
        
        viewController.title = _brand_;
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_ENCRYPTED;

        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
            
        [self presentViewController:navigationController animated:YES completion:nil];
    }
    
    // modello o plist con il title a 0 allora è andato storto qualcosa ... ricaricalo
    if (_metadata.cryptated && [_metadata.title length] == 0) {
    
        NSString* selector;
        
        if ([_metadata.type isEqualToString:metadataType_model]) selector = selectorLoadModelView;
        else selector = selectorLoadPlist;
        
        [[CCNetworking sharedNetworking] downloadFile:_metadata serverUrl:_localServerUrl downloadData:NO downloadPlist:YES selector:selector selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
        
        return;
    }
        
    // se il plist è caricato ed è un modello aprilo
    if ([_metadata.type isEqualToString:metadataType_model]) [self openModel:_metadata.model isNew:false];
    
    // file
    if (_metadata.directory == NO && _metadata.errorPasscode == NO && [_metadata.type isEqualToString:metadataType_file]) {
        
        // se il file esiste andiamo direttamente al delegato altrimenti carichiamolo
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, _metadata.fileID]]) {
                            
            [self downloadFileSuccess:_metadata.fileID serverUrl:_localServerUrl selector:selectorLoadFileView selectorPost:nil];
            
        } else {
                
            [[CCNetworking sharedNetworking] downloadFile:_metadata serverUrl:_localServerUrl downloadData:YES downloadPlist:NO selector:selectorLoadFileView selectorPost:nil session:download_session taskStatus:taskStatusResume delegate:self];
            
            NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:_metadata.fileID];
            if (indexPath) [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    if (_metadata.directory) [self performSegueDirectoryWithControlPasscode:true];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    [self setTitleNOAnimation];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Synchronize Cell =====
#pragma --------------------------------------------------------------------------------------------

- (void)synchronizedFolderGraphicsServerUrl:(NSString *)serverUrl animation:(BOOL)animation
{
    BOOL cryptated = NO;
    CCCellMain *cell;
    
    for (NSString* fileID in _sectionDataSource.allRecordsDataSource) {
        
        CCMetadata *recordMetadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (recordMetadata.directory == NO)
            continue;
        
        if ([[CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:recordMetadata.fileNameData] isEqualToString:serverUrl]) {
            
            NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:recordMetadata.fileID];
            cell = (CCCellMain *)[self.tableView cellForRowAtIndexPath:indexPath];
            cryptated = recordMetadata.cryptated;
                
            break;
        }
    }

    if (!cell)
        return;
    
    if (animation) {
        
        NSURL *myURL;
        
        if (cryptated)
            myURL = [[NSBundle mainBundle] URLForResource: @"synchronizedcrypto" withExtension:@"gif"];
        else
            myURL = [[NSBundle mainBundle] URLForResource: @"synchronized" withExtension:@"gif"];
        
        cell.synchronizedImageView.image = [UIImage animatedImageWithAnimatedGIFURL:myURL];
        
    } else {
        
        if (cryptated)
            cell.synchronizedImageView.image = [UIImage imageNamed:image_synchronizedcrypto];
        else
            cell.synchronizedImageView.image = [UIImage imageNamed:image_synchronized];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)shouldPerformSegue:(NSString *)serverUrl
{
    // if background return
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) return NO;
    
    // se non siamo in primo piano o se non siamo nella stessa directory esci
    if (self.view.window == NO || ([serverUrl isEqualToString:_localServerUrl] == NO && serverUrl))
        return NO;
    
    // Collapsed ma siamo già in detail esci
    if (self.splitViewController.isCollapsed)
        if (_detailViewController.isViewLoaded && _detailViewController.view.window) return NO;
    
    // Video in esecuzione esci
    if (_detailViewController.photoBrowser.currentVideoPlayerViewController.isViewLoaded && _detailViewController.photoBrowser.currentVideoPlayerViewController.view.window) return NO;
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id viewController = segue.destinationViewController;
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        
        UINavigationController *nav = viewController;
        _detailViewController = (CCDetail *)nav.topViewController;
        
    } else {
        
        _detailViewController = segue.destinationViewController;
    }
    
    NSMutableArray *allRecordsDataSourceImagesVideos = [[NSMutableArray alloc] init];
    for (NSString *fileID in _sectionDataSource.allFileID) {
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        if ([metadata.typeFile isEqualToString:metadataTypeFile_image] || [metadata.typeFile isEqualToString:metadataTypeFile_video])
            [allRecordsDataSourceImagesVideos addObject:metadata];
    }

    _detailViewController.delegate = self;
    _detailViewController.dataSourceImagesVideos = allRecordsDataSourceImagesVideos;
    _detailViewController.metadataDetail = _metadataSegue;
    _detailViewController.dateFilterQuery = nil;
    _detailViewController.isCameraUpload = NO;
    _detailViewController.sourceDirectory = sorceDirectoryAccount;
    
    [_detailViewController setTitle:_metadata.fileNamePrint];
}

// can i go to next viewcontroller
- (void)performSegueDirectoryWithControlPasscode:(BOOL)controlPasscode
{
    NSString *nomeDir;

    if(self.tableView.editing == NO && _metadata.errorPasscode == NO){
        
        NSString *lockServerUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:_metadata.fileNameData];
        
        // SE siamo in presenza di una directory bloccata E è attivo il block E la sessione password Lock è senza data ALLORA chiediamo la password per procedere
        if ([CCCoreData isDirectoryLock:lockServerUrl activeAccount:app.activeAccount] && [[CCUtility getBlockCode] length] && app.sessionePasscodeLock == nil && controlPasscode) {
            
            CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
            viewController.delegate = self;
            viewController.fromType = CCBKPasscodeFromLockDirectory;
            viewController.type = BKPasscodeViewControllerCheckPasscodeType;
            viewController.inputViewTitlePassword = YES;
            
            if ([CCUtility getSimplyBlockCode]) {
                
                viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
                viewController.passcodeInputView.maximumLength = 6;
                
            } else {
                
                viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
                viewController.passcodeInputView.maximumLength = 64;
            }

            BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:BKPasscodeKeychainServiceName];
            touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
            viewController.touchIDManager = touchIDManager;
            
            viewController.title = NSLocalizedString(@"_folder_blocked_", nil); 
            viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
            viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_ENCRYPTED;
            
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            [self presentViewController:navController animated:YES completion:nil];
            
            return;
        }
        
        if (_metadata.cryptated) nomeDir = [_metadata.fileName substringToIndex:[_metadata.fileName length]-6];
        else nomeDir = _metadata.fileName;
        
        NSString *serverUrl = [CCUtility stringAppendServerUrl:_localServerUrl addServerUrl:nomeDir];
        
        CCMain *viewController = [app.listMainVC objectForKey:serverUrl];
        
        if (viewController.isViewLoaded == false) {
            
            viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMainVC"];
            
            viewController.isFolderEncrypted = _metadata.cryptated;
            viewController.localServerUrl = serverUrl;
            viewController.titleMain = _metadata.fileNamePrint;
            viewController.textBackButton = _titleMain;
            
            // save self
            [app.listMainVC setObject:viewController forKey:serverUrl];
        }
                
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

@end

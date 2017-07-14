//
//  CCMain.m
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

#import "CCMain.h"
#import "AppDelegate.h"
#import "CCPhotos.h"
#import "CCSynchronize.h"
#import "CCTransfersCell.h"
#import "OCActivity.h"
#import "OCNotifications.h"
#import "OCNotificationsAction.h"
#import "OCFrameworkConstants.h"
#import "OCCapabilities.h"
#import "CTAssetCheckmark.h"
#import "NCAutoUpload.h"
#import "NCBridgeSwift.h"

@interface CCMain () <CCActionsDeleteDelegate, CCActionsRenameDelegate, CCActionsSearchDelegate, CCActionsDownloadThumbnailDelegate, CCActionsSettingFavoriteDelegate, UITextViewDelegate, createFormUploadAssetsDelegate, MGSwipeTableCellDelegate, CCLoginDelegate, CCLoginDelegateWeb>
{
    tableMetadata *_metadata;
    
    BOOL _isRoot;
    BOOL _isViewDidLoad;
    BOOL _isOfflineServerUrl;
    
    BOOL _isPickerCriptate;              // if is cryptated image or video back from picker
    BOOL _isSelectedMode;
        
    NSMutableDictionary *_selectedFileIDsMetadatas;
    NSUInteger _numSelectedFileIDsMetadatas;
    NSMutableArray *_queueSelector;
    
    NSMutableDictionary *_statusSwipeCell;
    
    UIImageView *_ImageTitleHomeCryptoCloud;
    UIView *_reMenuBackgroundView;
    UITapGestureRecognizer *_singleFingerTap;
    
    NSString *_directoryGroupBy;
    NSString *_directoryOrder;
    
    NSUInteger _failedAttempts;
    NSDate *_lockUntilDate;

    NSString *_fatherPermission;

    UIRefreshControl *_refreshControl;
    UIDocumentInteractionController *_docController;

    CCHud *_hud;
    CCHud *_hudDeterminate;
    
    // Datasource
    CCSectionDataSourceMetadata *_sectionDataSource;
    NSDate *_dateReadDataSource;
    
    // Search
    BOOL _isSearchMode;
    NSString *_searchFileName;
    NSMutableArray *_searchResultMetadatas;
    NSString *_depth;
    NSString *_noFilesSearchTitle;
    NSString *_noFilesSearchDescription;
    NSTimer *_timerWaitInput;

    // Login
    CCLoginWeb *_loginWeb;
    CCLogin *_loginVC;
    
    BOOL _loadingFolder;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setTitle) name:@"setTitleMain" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
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
    _metadata = [tableMetadata new];
    _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    _hudDeterminate = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    _selectedFileIDsMetadatas = [NSMutableDictionary new];
    _statusSwipeCell = [NSMutableDictionary new];
    _queueSelector = [NSMutableArray new];
    _isViewDidLoad = YES;
    _fatherPermission = @"";
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchResultMetadatas = [NSMutableArray new];
    _searchFileName = @"";
    _depth = @"infinity";
    _noFilesSearchTitle = @"";
    _noFilesSearchDescription = @"";
    
    // delegate
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.separatorColor = [NCBrandColor sharedInstance].seperator;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.searchController.delegate = self;
    self.searchController.searchBar.delegate = self;
    
    [[CCNetworking sharedNetworking] settingDelegate:self];
    
    // Custom Cell
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMain" bundle:nil] forCellReuseIdentifier:@"CellMain"];
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMainTransfer" bundle:nil] forCellReuseIdentifier:@"CellMainTransfer"];
    
    // long press recognizer TableView
    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressTableView:)];
    [self.tableView addGestureRecognizer:longPressRecognizer];
    
    // Pull-to-Refresh
    [self createRefreshControl];
    
    // Register for 3D Touch Previewing if available
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] && (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable))
    {
        [self registerForPreviewingWithDelegate:self sourceView:self.view];
    }

    // Back Button
    if ([_serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:app.activeUrl]])
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"navigationLogo"] style:UIBarButtonItemStylePlain target:nil action:nil];
    
    // reMenu Background
    _reMenuBackgroundView = [[UIView alloc] init];
    _reMenuBackgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    
    // if this is not Main (the Main uses inizializeMain)
    if (_isRoot == NO && app.activeAccount.length > 0) {
        
        // Settings this folder & delegate & Loading datasource
        app.directoryUser = [CCUtility getDirectoryActiveUser:app.activeUser activeUrl:app.activeUrl];
        
        // Load Datasource
        [self reloadDatasource:_serverUrl];
        
        // Read (File) Folder
        [self readFileReloadFolder];
    }
    
    // Title
    [self setTitle];
    
    // Search
    self.definesPresentationContext = YES;
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.barTintColor = [NCBrandColor sharedInstance].seperator;
    [self.searchController.searchBar sizeToFit];
    self.searchController.searchBar.delegate = self;
    
    // Hide Search Filed on Load
    self.tableView.tableHeaderView = self.searchController.searchBar;
    [self.tableView setContentOffset:CGPointMake(0, self.searchController.searchBar.frame.size.height - self.tableView.contentOffset.y)];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // test
    if (app.activeAccount.length == 0)
        return;
    
    // Settings this folder & delegate & Loading datasource
    app.directoryUser = [CCUtility getDirectoryActiveUser:app.activeUser activeUrl:app.activeUrl];
    
    [[CCNetworking sharedNetworking] settingDelegate:self];
    
    // Color
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:_isFolderEncrypted online:[app.reachability isReachable] hidden:NO];
    [app aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    if (_isSelectedMode)
        [self setUINavigationBarSelected];
    else
        [self setUINavigationBarDefault];
    
    // If not editing mode remove _selectedFileIDs
    if (!self.tableView.editing)
        [_selectedFileIDsMetadatas removeAllObjects];
    
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
        
        if (app.activeAccount.length > 0 && [_selectedFileIDsMetadatas count] == 0) {
        
            // Load Datasource
            [self reloadDatasource:_serverUrl];
            
            // Read (file) Folder
            [self readFileReloadFolder];
        }
    }

    // Title
    [self setTitle];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self closeAllMenu];
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

// detect scroll for remove keyboard in search mode
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (_isSearchMode && scrollView == self.tableView) {
        
        [self.searchController.searchBar endEditing:YES];
    }
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [app changeTheming:self];
    
    // Refresh control
    _refreshControl.tintColor = [NCBrandColor sharedInstance].brand;
    
    // Reload Table View
    [self tableViewReloadData];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Initizlize Mail =====
#pragma --------------------------------------------------------------------------------------------

- (void)initializeMain:(NSNotification *)notification
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    _directoryGroupBy = nil;
    _directoryOrder = nil;
    _dateReadDataSource = nil;
    
    // test
    if (app.activeAccount.length == 0)
        return;
    
    if ([app.listMainVC count] == 0 || _isRoot) {
        
        // This is Root home main add list
        appDelegate.homeMain = self;
        _isRoot = YES;
        _serverUrl = [CCUtility getHomeServerUrlActiveUrl:app.activeUrl];
        appDelegate.directoryUser = [CCUtility getDirectoryActiveUser:app.activeUser activeUrl:app.activeUrl];
        [appDelegate.listMainVC setObject:self forKey:_serverUrl];
        
        // go Home
        [self.navigationController popToRootViewControllerAnimated:NO];
        
        // Crypto Mode
        if ([[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] == 0) {
           
            appDelegate.isCryptoCloudMode = NO;
            
        } else {
         
            appDelegate.isCryptoCloudMode = YES;
        }
        _isFolderEncrypted = NO;
        
        // setting Networking
        [[CCNetworking sharedNetworking] settingDelegate:self];
        [[CCNetworking sharedNetworking] settingAccount];
        
        // Remove search mode
        [self cancelSearchBar];
        
        // populate shared Link & User
        NSArray *results = [[NCManageDatabase sharedInstance] getShares];
        if (results) {
            appDelegate.sharesLink = results[0];
            appDelegate.sharesUserAndGroup = results[1];
        }
        
        // Load Datasource
        [self reloadDatasource:_serverUrl];

        // Read (File) Folder
        [self readFileReloadFolder];
        
        // Setting Theming
        [app settingThemingColorBrand];
        
        // Load photo datasorce
        if (appDelegate.activePhotos)
            [appDelegate.activePhotos reloadDatasourceForced];
        
        // remove all of detail
        if (appDelegate.activeDetail)
            [appDelegate.activeDetail removeAllView];
        
        // remove all Notification Messages
        [appDelegate.listOfNotifications removeAllObjects];
        
        // Initializations
        [appDelegate applicationInitialized];
                
    } else {
        
        // reload datasource
        [self reloadDatasource:_serverUrl];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)emptyDataSetShouldAllowScroll:(UIScrollView *)scrollView
{
    if (_loadingFolder)
        return NO;
    else
        return YES;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIColor whiteColor];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    if (_isSearchMode)
        return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"searchBig"] color:[NCBrandColor sharedInstance].brand];
    else
        return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"filesNoFiles"] color:[NCBrandColor sharedInstance].brand];
}

- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView
{
    if (_loadingFolder && _refreshControl.isRefreshing == NO) {
    
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
        activityView.color = [NCBrandColor sharedInstance].brand;
        [activityView startAnimating];
        
        return activityView;
    }
    
    return nil;
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if (_isSearchMode) {
        
        text = _noFilesSearchTitle;
        
    } else {
        
        text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_files_no_files_", nil)];
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if (_isSearchMode) {
        
        text = _noFilesSearchDescription;
        
    } else {
        
        text = [NSString stringWithFormat:@"\n%@", NSLocalizedString(@"_no_file_pull_down_", nil)];
    }
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Text Field =====
#pragma --------------------------------------------------------------------------------------------

- (void)minCharTextFieldDidChange:(UITextField *)sender
{
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    
    if (alertController)
    {
        UITextField *fileName = alertController.textFields.firstObject;
        UIAlertAction *okAction = alertController.actions.lastObject;
        okAction.enabled = fileName.text.length > 0;
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField{
    [textField selectAll:textField];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Graphic Window =====
#pragma --------------------------------------------------------------------------------------------

- (void)createRefreshControl
{
    _refreshControl = [UIRefreshControl new];
    _refreshControl.tintColor = [NCBrandColor sharedInstance].brand;
    _refreshControl.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:235.0/255.0 blue:235.0/255.0 alpha:1.0];
    [_refreshControl addTarget:self action:@selector(refreshControlTarget) forControlEvents:UIControlEventValueChanged];
    [self setRefreshControl:_refreshControl];
}

- (void)deleteRefreshControl
{
    [_refreshControl endRefreshing];
    self.refreshControl = nil;
}

- (void)refreshControlTarget
{
    [self readFolder:_serverUrl];
    
    // Actuate `Peek` feedback (weak boom)
    AudioServicesPlaySystemSound(1519);
    
    [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:NO];
}

- (void)setTitle
{
    // Color text self.navigationItem.title
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:_isFolderEncrypted online:[app.reachability isReachable] hidden:NO];

    if (_isSelectedMode) {
        
        NSUInteger totali = [_sectionDataSource.allRecordsDataSource count];
        NSUInteger selezionati = [[self.tableView indexPathsForSelectedRows] count];
        
        self.navigationItem.titleView = nil;
        self.navigationItem.title = [NSString stringWithFormat:@"%@ : %lu / %lu", NSLocalizedString(@"_selected_", nil), (unsigned long)selezionati, (unsigned long)totali];

    } else {
        
        // we are in home : LOGO BRAND
        if ([_serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:app.activeUrl]]) {
            
            self.navigationItem.title = nil;
            
            if ([app.reachability isReachable] == NO)
                _ImageTitleHomeCryptoCloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"navigationLogoOffline"]];
            else
                _ImageTitleHomeCryptoCloud = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"navigationLogo"]];
            
            [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
            UITapGestureRecognizer *singleTap =  [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(menuLogo)];
            [singleTap setNumberOfTapsRequired:1];
            [_ImageTitleHomeCryptoCloud addGestureRecognizer:singleTap];
            
            self.navigationItem.titleView = _ImageTitleHomeCryptoCloud;
            
        } else {
        
            self.navigationItem.title = _titleMain;
        }
    }
}

- (void)setUINavigationBarDefault
{
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:_isFolderEncrypted online:[app.reachability isReachable] hidden:NO];
    
    UIBarButtonItem *buttonMore, *buttonNotification;
    
    // =
    buttonMore = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"navigationControllerMenu"] style:UIBarButtonItemStylePlain target:self action:@selector(toggleReMainMenu)];
    buttonMore.enabled = true;
    
    // <
    self.navigationController.navigationBar.hidden = NO;
    
    // Notification
    if ([app.listOfNotifications count] > 0) {
        
        buttonNotification = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"notification"] style:UIBarButtonItemStylePlain target:self action:@selector(viewNotification)];
        buttonNotification.tintColor = [NCBrandColor sharedInstance].navigationBarText;
        buttonNotification.enabled = true;
    }
    
    if (buttonNotification)
        self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonMore, buttonNotification, nil];
    else
        self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonMore, nil];

    self.navigationItem.leftBarButtonItem = nil;
}

- (void)setUINavigationBarSelected
{
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:_isFolderEncrypted online:[app.reachability isReachable] hidden:NO];
    
    UIImage *icon = [UIImage imageNamed:@"navigationControllerMenu"];
    UIBarButtonItem *buttonMore = [[UIBarButtonItem alloc] initWithImage:icon style:UIBarButtonItemStylePlain target:self action:@selector(toggleReSelectMenu)];

    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancelSelect)];
    
    self.navigationItem.leftBarButtonItem = leftButton;
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:buttonMore, nil];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [self closeAllMenu];
    
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
    }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)cancelSelect
{
    [self tableViewSelect:NO];
    [app.reSelectMenu close];
}

- (void)closeAllMenu
{
    // close Menu
    [app.reSelectMenu close];
    [app.reMainMenu close];
    
    // Close Menu Logo
    [CCMenuAccount dismissMenu];
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
        
        [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingForUploading error:&error byAccessor:^(NSURL *newURL) {
            
            NSString *fileName = [url lastPathComponent];
            NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@", app.directoryUser, fileName];
            NSData *data = [NSData dataWithContentsOfURL:newURL];
            
            if (data && error == nil) {
                
                if ([data writeToFile:fileNamePath options:NSDataWritingAtomic error:&error]) {
                    
                    // Upload File
                    [[CCNetworking sharedNetworking] uploadFile:fileName serverUrl:_serverUrl cryptated:_isPickerCriptate onlyPlist:NO session:k_upload_session taskStatus: k_taskStatusResume selector:nil selectorPost:nil errorCode:0 delegate:nil];
                    
                } else {
                    
                    [app messageNotification:@"_error_" description:error.description visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
                }
                
            } else {
                
                [app messageNotification:@"_error_" description:@"_read_file_error_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
            }
        }];
    }
}

- (void)openImportDocumentPicker
{
    UIDocumentMenuViewController *documentProviderMenu = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    
    documentProviderMenu.modalPresentationStyle = UIModalPresentationFormSheet;
    documentProviderMenu.popoverPresentationController.sourceView = self.view;
    documentProviderMenu.popoverPresentationController.sourceRect = self.view.bounds;
    documentProviderMenu.delegate = self;
    
    [self presentViewController:documentProviderMenu animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Assets Picker =====
#pragma --------------------------------------------------------------------------------------------

-(void)dismissFormUploadAssets
{
    [self reloadDatasource];
}

- (void)openAssetsPickerController
{
    CTAssetCheckmark *checkmark = [CTAssetCheckmark appearance];
    checkmark.tintColor = [NCBrandColor sharedInstance].brand;
    [checkmark setMargin:0.0 forVerticalEdge:NSLayoutAttributeRight horizontalEdge:NSLayoutAttributeTop];
    
    UINavigationBar *navBar = [UINavigationBar appearanceWhenContainedIn:[CTAssetsPickerController class], nil];
    [app aspectNavigationControllerBar:navBar encrypted:NO online:YES hidden:NO];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
        dispatch_async(dispatch_get_main_queue(), ^{
            
            CTAssetCheckmark *checkmark = [CTAssetCheckmark appearance];
            [checkmark setMargin:0.0 forVerticalEdge:NSLayoutAttributeRight horizontalEdge:NSLayoutAttributeBottom];
            
            // init picker
            CTAssetsPickerController *picker = [CTAssetsPickerController new];
            
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

- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldSelectAsset:(PHAsset *)asset
{
    if (picker.selectedAssets.count > k_pickerControllerMax) {
        
        [app messageNotification:@"_info_" description:@"_limited_dimension_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
        
        return NO;
    }
    
    return YES;
}

- (void)assetsPickerController:(CTAssetsPickerController *)picker didFinishPickingAssets:(NSMutableArray *)assets
{
    [picker dismissViewControllerAnimated:YES completion:^{
        
        CreateFormUploadAssets *form = [[CreateFormUploadAssets alloc] init:_titleMain serverUrl:_serverUrl assets:assets cryptated:_isPickerCriptate session:k_upload_session delegate:self];
        form.title = NSLocalizedString(@"_upload_photos_videos_", nil);
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:form];
        
        [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
                
        [self presentViewController:navigationController animated:YES completion:nil];        
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create New (OpenModel) =====
#pragma --------------------------------------------------------------------------------------------

- (void)openModel:(NSString *)tipo isNew:(BOOL)isnew
{
    UIViewController *viewController;
    NSString *fileName, *uuid, *fileID, *serverUrl;
    
    NSIndexPath *index = [self.tableView indexPathForSelectedRow];
    [self.tableView deselectRowAtIndexPath:index animated:NO];
    
    if (isnew) {
        
        fileName = nil;
        uuid = [CCUtility getUUID];
        fileID = nil;
        serverUrl = _serverUrl;
        
    } else {
        
        fileName = _metadata.fileName;
        uuid = _metadata.uuid;
        fileID = _metadata.fileID;
        serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    }
    
    if ([tipo isEqualToString:@"cartadicredito"])
        viewController = [[CCCartaDiCredito alloc] initWithDelegate:self fileName:fileName uuid:uuid fileID:fileID isLocal:NO serverUrl:serverUrl];
    
    if ([tipo isEqualToString:@"bancomat"])
        viewController = [[CCBancomat alloc] initWithDelegate:self fileName:fileName uuid:uuid fileID:fileID  isLocal:NO serverUrl:serverUrl];
    
    if ([tipo isEqualToString:@"contocorrente"])
        viewController = [[CCContoCorrente alloc] initWithDelegate:self fileName:fileName uuid:uuid fileID:fileID isLocal:NO serverUrl:serverUrl];
    
    if ([tipo isEqualToString:@"accountweb"])
        viewController = [[CCAccountWeb alloc] initWithDelegate:self fileName:fileName uuid:uuid fileID:fileID isLocal:NO serverUrl:serverUrl];
    
    if ([tipo isEqualToString:@"patenteguida"])
        viewController = [[CCPatenteGuida alloc] initWithDelegate:self fileName:fileName uuid:uuid fileID:fileID isLocal:NO serverUrl:serverUrl];
    
    if ([tipo isEqualToString:@"cartaidentita"])
        viewController = [[CCCartaIdentita alloc] initWithDelegate:self fileName:fileName uuid:uuid fileID:fileID isLocal:NO serverUrl:serverUrl];
    
    if ([tipo isEqualToString:@"passaporto"])
        viewController = [[CCPassaporto alloc] initWithDelegate:self fileName:fileName uuid:uuid fileID:fileID isLocal:NO serverUrl:serverUrl];
    
    if ([tipo isEqualToString:@"note"]) {
        
        viewController = [[CCNote alloc] initWithDelegate:self fileName:fileName uuid:uuid fileID:fileID isLocal:NO serverUrl:serverUrl];
        
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
    switch (type) {
            
        /* PLAIN */
        case k_returnCreateFolderPlain: {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_create_folder_",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                
                textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            }];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                NSLog(@"Cancel action");
            }];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                
                UITextField *fileName = alertController.textFields.firstObject;
                [self createFolder:fileName.text autoUploadDirectory:NO];
            }];
            
            okAction.enabled = NO;
            
            [alertController addAction:cancelAction];
            [alertController addAction:okAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
        }
            break;
        case k_returnCreateFotoVideoPlain: {
            
            _isPickerCriptate = false;
            
            [self openAssetsPickerController];
        }
            break;
        case k_returnCreateFilePlain: {
            
            _isPickerCriptate = false;
            
            [self openImportDocumentPicker];
        }
            break;
            
        /* ENCRYPTED */
        case k_returnCreateFolderEncrypted: {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_create_folder_",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            }];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                NSLog(@"Cancel action");
            }];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                
                UITextField *fileName = alertController.textFields.firstObject;
                
                [self createFolderEncrypted:fileName.text];
            }];
            
            okAction.enabled = NO;
            
            [alertController addAction:cancelAction];
            [alertController addAction:okAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
        }
            break;
        case k_returnCreateFotoVideoEncrypted: {
            
            _isPickerCriptate = true;
            
            [self openAssetsPickerController];
        }
            break;
        case k_returnCreateFileEncrypted: {
            
            _isPickerCriptate = true;
            
            [self openImportDocumentPicker];
        }
            break;
    
        /* UTILITY */
        case k_returnNote:
            [self openModel:@"note" isNew:true];
            break;
        case k_returnAccountWeb:
            [self openModel:@"accountweb" isNew:true];
            break;
            
         /* BANK */
        case k_returnCartaDiCredito:
            [self openModel:@"cartadicredito" isNew:true];
            break;
        case k_returnBancomat:
            [self openModel:@"bancomat" isNew:true];
            break;
        case k_returnContoCorrente:
            [self openModel:@"contocorrente" isNew:true];
            break;
       
        /* DOCUMENT */
        case k_returnPatenteGuida:
            [self openModel:@"patenteguida" isNew:true];
            break;
        case k_returnCartaIdentita:
            [self openModel:@"cartaidentita" isNew:true];
            break;
        case k_returnPassaporto:
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
        [app messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
    else
        [app messageNotification:@"_save_selected_files_" description:@"_file_saved_cameraroll_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess errorCode:error.code];
}

- (void)saveSelectedFiles
{
    if (_isSelectedMode && [_selectedFileIDsMetadatas count] == 0)
        return;

    NSLog(@"[LOG] Start download selected files ...");
    
    [_hud visibleHudTitle:@"" mode:MBProgressHUDModeIndeterminate color:nil];
    
    NSArray *metadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        for (tableMetadata *metadata in metadatas) {
            
            if (metadata.directory == NO && [metadata.type isEqualToString: k_metadataType_file] && ([metadata.typeFile isEqualToString: k_metadataTypeFile_image] || [metadata.typeFile isEqualToString: k_metadataTypeFile_video])) {
                
                NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
                
                [[CCNetworking sharedNetworking] downloadFile:metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorSave selectorPost:nil session:k_download_session taskStatus: k_taskStatusResume delegate:self];
            }
        }
        
        [_hud hideHud];
    });
    
    [self tableViewSelect:NO];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Change Password =====
#pragma --------------------------------------------------------------------------------------------

- (void) loginSuccess:(NSInteger)loginType
{
    [self readFolder:_serverUrl];
}

- (void)changePasswordAccount
{
    // Brand
    if ([NCBrandOptions sharedInstance].use_login_web) {
    
        _loginWeb = [CCLoginWeb new];
        _loginWeb.delegate = self;
        _loginWeb.loginType = loginModifyPasswordUser;
    
        dispatch_async(dispatch_get_main_queue(), ^ {
            [_loginWeb presentModalWithDefaultTheme:self];
        });
        
    } else {
        
        _loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
        _loginVC.delegate = self;
        _loginVC.loginType = loginModifyPasswordUser;
    
        [self presentViewController:_loginVC animated:YES completion:nil];
    }
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Peek & Pop  =====
#pragma --------------------------------------------------------------------------------------------

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (metadata.thumbnailExists && !metadata.cryptated) {
        CCCellMain *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        if (cell) {
            previewingContext.sourceRect = cell.frame;
            CCPeekPop *vc = [[UIStoryboard storyboardWithName:@"CCPeekPop" bundle:nil] instantiateViewControllerWithIdentifier:@"PeekPopImagePreview"];
            
            vc.delegate = self;
            vc.metadata = metadata;
            
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
#pragma mark ==== External Sites ====
#pragma --------------------------------------------------------------------------------------------

- (void)getExternalSitesServerSuccess:(NSArray *)listOfExternalSites
{
    [[NCManageDatabase sharedInstance] deleteExternalSites];
    
    for (OCExternalSites *tableExternalSites in listOfExternalSites)
        [[NCManageDatabase sharedInstance] addExternalSites:tableExternalSites];
}

- (void)getExternalSitesServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"[LOG] No External Sites found");
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Activity ====
#pragma --------------------------------------------------------------------------------------------

- (void)getActivityServerSuccess:(NSArray *)listOfActivity
{
    [[NCManageDatabase sharedInstance] addActivityServer:listOfActivity];
    
    // Reload Activity Data Source
    [app.activeActivity reloadDatasource];
}

- (void)getActivityServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"[LOG] No Activity found");
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Notification  ====
#pragma --------------------------------------------------------------------------------------------

- (void)getNotificationServerSuccess:(NSArray *)listOfNotifications
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        // Order by date
        NSArray *sortedListOfNotifications = [listOfNotifications sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            
            OCNotifications *notification1 = obj1, *notification2 = obj2;
        
            return [notification2.date compare: notification1.date];
        
        }];
    
        // verify if listOfNotifications is changed
        NSString *old = @"", *new = @"";
        for (OCNotifications *notification in listOfNotifications)
            new = [new stringByAppendingString:@(notification.idNotification).stringValue];
        for (OCNotifications *notification in appDelegate.listOfNotifications)
            old = [old stringByAppendingString:@(notification.idNotification).stringValue];

        if (![new isEqualToString:old]) {
        
            appDelegate.listOfNotifications = [[NSMutableArray alloc] initWithArray:sortedListOfNotifications];
        
            // reload Notification view
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"notificationReloadData" object:nil];
        }
    
        // Update NavigationBar
        if (!_isSelectedMode) {
            
            [self performSelectorOnMainThread:@selector(setUINavigationBarDefault) withObject:nil waitUntilDone:NO];
        }
    });
}

- (void)getNotificationServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{    
    // Update NavigationBar
    if (!_isSelectedMode)
        [self setUINavigationBarDefault];
}

- (void)viewNotification
{
    if ([app.listOfNotifications count] > 0) {
        
        CCNotification *notificationVC = [[UIStoryboard storyboardWithName:@"CCNotification" bundle:nil] instantiateViewControllerWithIdentifier:@"CCNotification"];
        
        [notificationVC setModalPresentationStyle:UIModalPresentationFormSheet];

        [self presentViewController:notificationVC animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== User Profile  ====
#pragma --------------------------------------------------------------------------------------------

- (void)getUserProfileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    if (errorCode == 401)
        [self changePasswordAccount];
}

- (void)getUserProfileSuccess:(CCMetadataNet *)metadataNet userProfile:(OCUserProfile *)userProfile
{
    [[NCManageDatabase sharedInstance] setAccountsUserProfile:userProfile];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        NSString *address = [NSString stringWithFormat:@"%@/index.php/avatar/%@/128", app.activeUrl, app.activeUser];
        UIImage *avatar = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:[address stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]]];
        if (avatar)
            [UIImagePNGRepresentation(avatar) writeToFile:[NSString stringWithFormat:@"%@/avatar.png", app.directoryUser] atomically:YES];
        else
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/avatar.png", app.directoryUser] error:nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"changeUserProfile" object:nil];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Capabilities  ====
#pragma --------------------------------------------------------------------------------------------

- (void)getCapabilitiesOfServerFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Change Theming color
    [app settingThemingColorBrand];
    
    if (errorCode == 401)
        [self changePasswordAccount];
}

- (void)getCapabilitiesOfServerSuccess:(OCCapabilities *)capabilities
{
    // Update capabilities db
    [[NCManageDatabase sharedInstance] addCapabilities:capabilities];
    
    // ------ THEMING -----------------------------------------------------------------------
    
    // Download Theming Background & Change Theming color
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        if ([NCBrandOptions sharedInstance].use_themingBackground == YES) {
        
            UIImage *themingBackground = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:[capabilities.themingBackground stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]]];
            if (themingBackground)
                [UIImagePNGRepresentation(themingBackground) writeToFile:[NSString stringWithFormat:@"%@/themingBackground.png", app.directoryUser] atomically:YES];
            else
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/themingBackground.png", app.directoryUser] error:nil];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [app settingThemingColorBrand];
        });
    });

    // ------ SEARCH  ------------------------------------------------------------------------
    
    // Search bar if change version
    if ([[NCManageDatabase sharedInstance] getServerVersion] != capabilities.versionMajor) {
    
        [self cancelSearchBar];
    }
    
    // ------ GET SERVICE SERVER ------------------------------------------------------------
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];

    // Read External Sites
    if (capabilities.isExternalSitesServerEnabled) {
        
        metadataNet.action = actionGetExternalSitesServer;
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
    
    // Read Share
    if (capabilities.isFilesSharingAPIEnabled) {
        
        [app.sharesID removeAllObjects];
        metadataNet.action = actionReadShareServer;
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
    
    // Read Notification
    metadataNet.action = actionGetNotificationServer;
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    // Read User Profile
    metadataNet.action = actionGetUserProfile;
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    // Read Activity
    metadataNet.action = actionGetActivityServer;
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Request Server Information  ====
#pragma --------------------------------------------------------------------------------------------

- (void)requestServerCapabilities
{
    // test
    if (app.activeAccount.length == 0)
        return;
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionGetCapabilities;
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Middleware Ping  ====
#pragma --------------------------------------------------------------------------------------------

- (void)middlewarePing
{
    // test
    if (app.activeAccount.length == 0)
        return;
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionMiddlewarePing;
    metadataNet.serverUrl = [[NCBrandOptions sharedInstance] middlewarePingUrl];
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail Delegate ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnailSuccess:(CCMetadataNet *)metadataNet
{
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadataNet.fileID];
    
    if ([self indexPathIsValid:indexPath]) {
    
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadataNet.fileID]])
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadFileFailure:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
    
    // File do not exists on server, remove in local
    if (errorCode == kOCErrorServerPathNotFound || errorCode == kCFURLErrorBadServerResponse) {
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, fileID] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, fileID] error:nil];

        if (metadata.directory && serverUrl) {
            
            NSString *dirForDelete = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileNameData];
            
            [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:dirForDelete];
        }

        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID] clearDateReadDirectoryID:nil];
        [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
    }
    
    if ([selector isEqualToString:selectorLoadViewImage]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{

            // Updating Detail
            if (app.activeDetail)
                [app.activeDetail downloadPhotoBrowserFailure:errorCode];
            
            // Updating Photos
            if (app.activePhotos)
                [app.activePhotos downloadFileFailure:errorCode];
        });
        
    } else {
        
        if (errorCode != kCFURLErrorCancelled)
            [app messageNotification:@"_download_file_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    }

    [self reloadDatasource:serverUrl];
}

- (void)downloadFileSuccess:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    __block tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
    
    if (metadata == nil)
        return;
    
    // Download
    if ([selector isEqualToString:selectorDownloadFile]) {
        [self reloadDatasource:serverUrl];
    }
    
    // Synchronized
    if ([selector isEqualToString:selectorDownloadSynchronize]) {
        [self reloadDatasource:serverUrl];
    }
    
    // add Favorite
    if ([selector isEqualToString:selectorAddFavorite]) {
        [[CCActions sharedInstance] settingFavorite:metadata favorite:YES delegate:self];
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
        
        [self reloadDatasource:serverUrl];
        
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_compress]) {
            
            selector = selectorOpenIn;
            //[self performSelector:@selector(unZipFile:) withObject:metadata.fileID];
            
        } else if ([metadata.typeFile isEqualToString: k_metadataTypeFile_unknown]) {
            
            selector = selectorOpenIn;
           
        } else {
            
            _metadata = metadata;
    
            if ([self shouldPerformSegue])
                [self performSegueWithIdentifier:@"segueDetail" sender:self];
        }
    }
    
    // addLocal
    if ([selector isEqualToString:selectorAddLocal]) {
        
        [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] toPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryLocal], metadata.fileNamePrint]];
        
        UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        [CCGraphics saveIcoWithEtag:metadata.fileNamePrint image:image writeToFile:nil copy:YES move:NO fromPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID] toPath:[NSString stringWithFormat:@"%@/.%@.ico", [CCUtility getDirectoryLocal], metadata.fileNamePrint]];
        
        [app messageNotification:@"_add_local_" description:@"_file_saved_local_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess errorCode:0];
        
        [self reloadDatasource:serverUrl];
    }
    
    // Open with...
    if ([selector isEqualToString:selectorOpenIn] && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        
        [self reloadDatasource:serverUrl];
        
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
        
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image]) {
            
            UIImage *image = [UIImage imageWithContentsOfFile:file];
            
            if (image)
                UIImageWriteToSavedPhotosAlbum(image, self, @selector(saveSelectedFilesSelector: didFinishSavingWithError: contextInfo:), nil);
            else
                [app messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
        }
        
        if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video]) {
                        
            [[NSFileManager defaultManager] linkItemAtPath:file toPath:[NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint] error:nil];
            
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum([NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint])) {
                
                UISaveVideoAtPathToSavedPhotosAlbum([NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint], self, @selector(saveSelectedFilesSelector: didFinishSavingWithError: contextInfo:), nil);
            } else {
                [app messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
            }
        }
        
        [self reloadDatasource:serverUrl];
    }
    
    // Copy File
    if ([selector isEqualToString:selectorLoadCopy]) {
        
        [self reloadDatasource:serverUrl];
        
        [self copyFileToPasteboard:metadata];
    }
    
    // download and view a template
    if ([selector isEqualToString:selectorLoadModelView]) {
        
        // se è un template aggiorniamo anche nel FileSystem
        if ([metadata.type isEqualToString: k_metadataType_template]) {
            [[NCManageDatabase sharedInstance] setLocalFileWithFileID:metadata.fileID date:metadata.date exifDate:nil exifLatitude:nil exifLongitude:nil fileName:nil fileNamePrint:metadata.fileNamePrint];
        }
        
        [self openModel:metadata.model isNew:false];
    
        [self reloadDatasource:serverUrl];
    }
    
    //download file plist
    if ([selector isEqualToString:selectorLoadPlist]) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
            long countSelectorLoadPlist = 0;
        
            for (NSOperation *operation in [app.netQueue operations]) {
            
                if ([((OCnetworking *)operation).metadataNet.selector isEqualToString:selectorLoadPlist])
                    countSelectorLoadPlist++;
            }
            
            if ((countSelectorLoadPlist == 0 || countSelectorLoadPlist % k_maxConcurrentOperation == 0) && [metadata.directoryID isEqualToString:[[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl]]) {
            
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self reloadDatasource:serverUrl];
                });
            }
        });
    }
    
    //selectorLoadViewImage
    if ([selector isEqualToString:selectorLoadViewImage]) {
        
        // Detail
        if (app.activeDetail)
            [app.activeDetail downloadPhotoBrowserSuccess:metadata selector:selector];
            
        // Photos
        if (app.activePhotos)
            [app.activePhotos downloadFileSuccess:metadata];

        [self reloadDatasource:serverUrl];
    }
    
    // if exists postselector call self with selectorPost
    if ([selectorPost length] > 0)
        [self downloadFileSuccess:fileID serverUrl:serverUrl selector:selectorPost selectorPost:nil];
}

- (void)downloadSelectedFilesFolders
{
    if (_isSelectedMode && [_selectedFileIDsMetadatas count] == 0)
        return;

    NSLog(@"[LOG] Start download selected ...");
    
    [_hud visibleHudTitle:NSLocalizedString(@"_downloading_progress_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        for (tableMetadata *metadata in selectedMetadatas) {
            
            if ([metadata.type isEqualToString: k_metadataType_file]) {
                
                if (metadata.directory) {
                    
                    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
                    serverUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileName];
                    [[CCSynchronize sharedSynchronize] synchronizedFolder:serverUrl selector:selectorReadFolderWithDownload];
                    
                } else {
                    
                    [[CCSynchronize sharedSynchronize] synchronizedFile:metadata selector:selectorReadFileWithDownload];
                }
            }
        }
        
        [_hud hideHud];
    });
    
    [self tableViewSelect:NO];
}

- (void)downloadPlist:(NSString *)directoryID serverUrl:(NSString *)serverUrl
{
    NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND session = ''", app.activeAccount, directoryID] sorted:nil ascending:NO];
    
    for (tableMetadata *metadata in metadatas) {
            
        if ([CCUtility isCryptoPlistString:metadata.fileName] && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileName]] == NO && [metadata.session length] == 0) {
        
            CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
                
            metadataNet.action = actionDownloadFile;
            metadataNet.downloadData = NO;
            metadataNet.downloadPlist = YES;
            metadataNet.fileID = metadata.fileID;
            metadataNet.selector = selectorLoadPlist;
            metadataNet.serverUrl = serverUrl;
            metadataNet.session = k_download_session_foreground;
            metadataNet.taskStatus = k_taskStatusResume;
            
            [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
            
            //[[CCNetworking sharedNetworking] downloadFile:metadata.fileID serverUrl:serverUrl downloadData:NO downloadPlist:YES selector:selectorLoadPlist selectorPost:nil session:k_download_session_foreground taskStatus:k_taskStatusResume delegate:self];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Upload new Photos/Videos =====
#pragma --------------------------------------------------------------------------------------------

- (void)uploadFileFailure:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Auto Upload
    if([selector isEqualToString:selectorUploadAutoUpload] || [selector isEqualToString:selectorUploadAutoUploadAll]) {
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
            
            // ONLY BACKGROUND
            [[NCAutoUpload sharedInstance] performSelectorOnMainThread:@selector(loadAutoUpload:) withObject:[NSNumber numberWithInt:k_maxConcurrentOperationDownloadUploadBackground] waitUntilDone:NO];
            
        } else {
            
            // ONLY FOREFROUND
            [[NCAutoUpload sharedInstance] performSelectorOnMainThread:@selector(loadAutoUpload:) withObject:[NSNumber numberWithInt:k_maxConcurrentOperationDownloadUpload] waitUntilDone:NO];
        }
    }
    
    // Read File test do not exists
    if (errorCode == k_CCErrorFileUploadNotFound && fileID) {
       
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
        // reUpload
        if (metadata)
            [[CCNetworking sharedNetworking] uploadFileMetadata:metadata taskStatus:k_taskStatusResume];
    }
    
    // Print error
    else if (errorCode != kCFURLErrorCancelled && errorCode != 403) {
        
        [app messageNotification:@"_upload_file_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    }
    
    [self reloadDatasource:serverUrl];
}

- (void)uploadFileSuccess:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    // Auto Upload
    if([selector isEqualToString:selectorUploadAutoUpload] || [selector isEqualToString:selectorUploadAutoUploadAll]) {
    
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        
            // ONLY BACKGROUND
            [[NCAutoUpload sharedInstance] performSelectorOnMainThread:@selector(loadAutoUpload:) withObject:[NSNumber numberWithInt:k_maxConcurrentOperationDownloadUploadBackground] waitUntilDone:NO];
        
        } else {
        
            // ONLY FOREFROUND
            [[NCAutoUpload sharedInstance] performSelectorOnMainThread:@selector(loadAutoUpload:) withObject:[NSNumber numberWithInt:k_maxConcurrentOperationDownloadUpload] waitUntilDone:NO];
        }
    }
    
    if ([selectorPost isEqualToString:selectorReadFolderForced] ) {
            
        [self readFolder:serverUrl];
            
    } else {
    
        [self reloadDatasource:serverUrl];
    }
}

//
// This procedure with performSelectorOnMainThread it's necessary after (Bridge) for use the function "Sync" in OCNetworking
//
- (void)uploadFileAsset:(NSMutableArray *)assets serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated useSubFolder:(BOOL)useSubFolder session:(NSString *)session
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        [self performSelectorOnMainThread:@selector(uploadFileAssetBridge:) withObject:@[assets, serverUrl, [NSNumber numberWithBool:cryptated], [NSNumber numberWithBool:useSubFolder], session] waitUntilDone:NO];
    });
}

- (void)uploadFileAssetBridge:(NSArray *)arguments
{
    NSArray *assets = [arguments objectAtIndex:0];
    NSString *serverUrl = [arguments objectAtIndex:1];
    BOOL cryptated = [[arguments objectAtIndex:2] boolValue];
    BOOL useSubFolder = [[arguments objectAtIndex:3] boolValue];
    NSString *session = [arguments objectAtIndex:4];
    
    NSString *autoUploadPath = [[NCManageDatabase sharedInstance] getAccountAutoUploadPath:app.activeUrl];
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl];
    
    // Create the folder for Photos & if request the subfolders
    if (![[NCAutoUpload sharedInstance] createFolderSubFolderAutoUploadFolderPhotos:autoUploadPath useSubFolder:useSubFolder assets:(PHFetchResult *)assets selector:selectorUploadFile])
        return;
    
    NSLog(@"[LOG] Asset N. %lu", (unsigned long)[assets count]);
    
    for (PHAsset *asset in assets) {
        
        NSString *fileName = [CCUtility createFileNameFromAsset:asset key: k_keyFileNameMask];
        
        NSDate *assetDate = asset.creationDate;
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        
        // Create serverUrl if use sub folder
        if (useSubFolder) {
            
            [formatter setDateFormat:@"yyyy"];
            NSString *yearString = [formatter stringFromDate:assetDate];
        
            [formatter setDateFormat:@"MM"];
            NSString *monthString = [formatter stringFromDate:assetDate];
            
            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", autoUploadPath, yearString, monthString];
        }
        
        // Check if is in upload 
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND fileName = %@ AND session != ''", app.activeAccount, directoryID, fileName];
        NSArray *isRecordInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:predicate sorted:nil ascending:NO];

        if ([isRecordInSessions count] > 0) {
            
            // next upload
            continue;
            
        } else {
            
            CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
            if (cryptated) {
                
                metadataNet.action = actionUploadAsset;
                metadataNet.assetLocalIdentifier = asset.localIdentifier;
                metadataNet.cryptated = cryptated;
                metadataNet.fileName = fileName;
                metadataNet.session = session;
                metadataNet.selector = selectorUploadFile;
                metadataNet.selectorPost = nil;
                metadataNet.serverUrl = serverUrl;
                metadataNet.taskStatus = k_taskStatusResume;

            } else {
            
                metadataNet.action = actionReadFile;
                metadataNet.assetLocalIdentifier = asset.localIdentifier;
                metadataNet.cryptated = cryptated;
                metadataNet.fileName = fileName;
                metadataNet.session = session;
                metadataNet.selector = selectorReadFileUploadFile;
                metadataNet.serverUrl = serverUrl;
            }
            
            [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Read File ====
#pragma --------------------------------------------------------------------------------------------

- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // Read Folder
    if ([metadataNet.selector isEqualToString:selectorReadFileReloadFolder]) {
        //[self readFolderWithForced:NO serverUrl:metadataNet.serverUrl];
    }
    
    // UploadFile
    if ([metadataNet.selector isEqualToString:selectorReadFileUploadFile]) {
        
        // File not exists
        if (errorCode == 404) {
            
            metadataNet.action = actionUploadAsset;
            metadataNet.errorCode = 0;
            metadataNet.selector = selectorUploadFile;
            metadataNet.selectorPost = nil;
            metadataNet.taskStatus = k_taskStatusResume;
            
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
                [app messageNotification:@"_upload_file_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
            }
        }
    }
}

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(tableMetadata *)metadata
{
    // Read Folder
    if ([metadataNet.selector isEqualToString:selectorReadFileReloadFolder]) {
        
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", metadataNet.account, metadataNet.serverUrl]];
        
        if ([metadata.etag isEqualToString:directory.etag] == NO) {
            [self readFolder:metadataNet.serverUrl];
        }
    }
    
    // UploadFile
    if ([metadataNet.selector isEqualToString:selectorReadFileUploadFile]) {
        
        metadataNet.action = actionUploadAsset;
        metadataNet.errorCode = 403;                // File exists 403 Forbidden
        metadataNet.selector = selectorUploadFile;
        metadataNet.selectorPost = nil;
        metadataNet.taskStatus = k_taskStatusResume;
        
        if ([metadataNet.session containsString:@"wwan"])
            [app addNetworkingOperationQueue:app.netQueueUploadWWan delegate:self metadataNet:metadataNet];
        else
            [app addNetworkingOperationQueue:app.netQueueUpload delegate:self metadataNet:metadataNet];
    }
}

- (void)readFileReloadFolder
{
    if (!_serverUrl || !app.activeAccount || app.maintenanceMode)
        return;
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];

    metadataNet.action = actionReadFile;
    metadataNet.priority = NSOperationQueuePriorityHigh;
    metadataNet.selector = selectorReadFileReloadFolder;
    metadataNet.serverUrl = _serverUrl;

    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Read Folder ====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    // verify active user
    tableAccount *record = [[NCManageDatabase sharedInstance] getAccountActive];
    
    _loadingFolder = NO;
    [self tableViewReloadData];

    [_refreshControl endRefreshing];
        
    [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
    
    if (message && [record.account isEqualToString:metadataNet.account])
        [app messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    
    [self reloadDatasource:metadataNet.serverUrl];
    
    if (errorCode == 401)
        [self changePasswordAccount];
}

- (void)readFolderSuccess:(CCMetadataNet *)metadataNet metadataFolder:(tableMetadata *)metadataFolder metadatas:(NSArray *)metadatas
{
    // verify active user
    tableAccount *record = [[NCManageDatabase sharedInstance] getAccountActive];

    if (![record.account isEqualToString:metadataNet.account])
        return;
    
    // save father e update permission
    if(!_isSearchMode && metadataFolder)
        _fatherPermission = metadataFolder.permissions;
    
    NSArray *recordsInSessions;
    NSMutableArray *metadatasToInsertInDB = [NSMutableArray new];
    
    if (_isSearchMode) {
        
        recordsInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND session != ''", metadataNet.account] sorted:nil ascending:NO];
        
    } else {
        
        [[NCManageDatabase sharedInstance] setDirectoryWithServerUrl:metadataNet.serverUrl serverUrlTo:nil etag:metadataFolder.etag];
        
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND session = ''", metadataNet.account, metadataNet.directoryID] clearDateReadDirectoryID:metadataNet.directoryID];
        
        recordsInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND session != ''", metadataNet.account, metadataNet.directoryID] sorted:nil ascending:NO];

        [[NCManageDatabase sharedInstance] setDateReadDirectoryWithDirectoryID:metadataNet.directoryID];
    }
    
    for (tableMetadata *metadata in metadatas) {
        
        // type of file
        NSInteger typeFilename = [CCUtility getTypeFileName:metadata.fileName];
        
        // if crypto do not insert
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
        
        // verify if the record is in download/upload progress
        if (metadata.directory == NO && [recordsInSessions count] > 0) {
            
            tableMetadata *metadataTransfer = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND fileName = %@", app.activeAccount, metadataNet.directoryID, metadata.fileName]];
            
            // is in Download or Upload
            if ([metadataTransfer.session containsString:@"upload"] || [metadataTransfer.session containsString:@"download"]) {
                continue;
            }
        }
        
        // Insert in Array
        [metadatasToInsertInDB addObject:metadata];
    }
    
    // insert in Database
    metadatasToInsertInDB = (NSMutableArray *)[[NCManageDatabase sharedInstance] addMetadatas:metadatasToInsertInDB activeUrl:app.activeUrl serverUrl:metadataNet.serverUrl];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        // read plist
        if (!_isSearchMode)
            [self downloadPlist:metadataNet.directoryID serverUrl:metadataNet.serverUrl];

        // File is changed ??
        if (!_isSearchMode && metadatasToInsertInDB)
            [[CCSynchronize sharedSynchronize] verifyChangeMedatas:metadatasToInsertInDB serverUrl:metadataNet.serverUrl account:app.activeAccount withDownload:NO];
    });
    
    // Search Mode
    if (_isSearchMode) {
        
        // Fix managed -> Unmanaged _searchResultMetadatas
        _searchResultMetadatas = [[NSMutableArray alloc] initWithArray:metadatasToInsertInDB];
        
        [self reloadDatasource:metadataNet.serverUrl];
    }
    
    // this is the same directory
    if ([metadataNet.serverUrl isEqualToString:_serverUrl] && !_isSearchMode) {
        
        // reload
        [self reloadDatasource:metadataNet.serverUrl];
    
        // stoprefresh
        [_refreshControl endRefreshing];
    
        // Enable change user
        [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:YES];
                
        _loadingFolder = NO;
        [self tableViewReloadData];
    }
}

- (void)readFolder:(NSString *)serverUrl
{
    // init control
    if (!serverUrl || !app.activeAccount || app.maintenanceMode) {
        
        [_refreshControl endRefreshing];
        return;
    }
    
    // Search Mode
    if (_isSearchMode) {
        
        [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:serverUrl directoryID:nil];
            
        _searchFileName = @"";                          // forced reload searchg
        
        [self updateSearchResultsForSearchController:self.searchController];
        
        return;
    }
    
    _loadingFolder = YES;
    [self tableViewReloadData];
    
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", app.activeAccount, serverUrl]];
    
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];

    metadataNet.action = actionReadFolder;
    metadataNet.date = [NSDate date];
    metadataNet.directoryID = directory.directoryID;
    metadataNet.priority = NSOperationQueuePriorityHigh;
    metadataNet.selector = selectorReadFolder;
    metadataNet.serverUrl = serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Search =====
#pragma --------------------------------------------------------------------------------------------

-(void)searchStartTimer
{
    NSString *home = [CCUtility getHomeServerUrlActiveUrl:app.activeUrl];
    
    [[CCActions sharedInstance] search:home fileName:_searchFileName depth:_depth date:nil selector:selectorSearch delegate:self];

    _noFilesSearchTitle = @"";
    _noFilesSearchDescription = NSLocalizedString(@"_search_in_progress_", nil);
    
    [self.tableView reloadEmptyDataSet];
}

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];

    _isSearchMode = YES;
    [self deleteRefreshControl];
    
    NSString *fileName = [CCUtility removeForbiddenCharactersServer:searchController.searchBar.text];
    
    if (fileName.length >= k_minCharsSearch && [fileName isEqualToString:_searchFileName] == NO) {
        
        _searchFileName = fileName;
        
        // First : filter
            
        NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"directoryID = %@ AND account = %@ AND fileNamePrint CONTAINS[cd] %@", directoryID, app.activeAccount, fileName];
        NSArray *records = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:predicate sorted:nil ascending:NO];
            
        [_searchResultMetadatas removeAllObjects];
        for (tableMetadata *record in records)
            [_searchResultMetadatas addObject:record];
            
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
        metadataNet.account = app.activeAccount;
        metadataNet.directoryID = directoryID;
        metadataNet.selector = selectorSearch;
        metadataNet.serverUrl = _serverUrl;

        [self readFolderSuccess:metadataNet metadataFolder:nil metadatas:_searchResultMetadatas];
    
        // Version >= 12
        if ([[NCManageDatabase sharedInstance] getServerVersion] >= 12) {
            
            [_timerWaitInput invalidate];
            _timerWaitInput = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(searchStartTimer) userInfo:nil repeats:NO];
        }
    }
    
    if (_searchResultMetadatas.count == 0 && fileName.length == 0) {

        [self reloadDatasource];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self cancelSearchBar];
    
    [self readFolder:_serverUrl];
}

- (void)searchFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    _searchFileName = @"";

    if (message)
        [app messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
}

- (void)searchSuccess:(CCMetadataNet *)metadataNet metadatas:(NSArray *)metadatas
{
    _searchResultMetadatas = [[NSMutableArray alloc] initWithArray:metadatas];
    
    [self readFolderSuccess:metadataNet metadataFolder:nil metadatas:metadatas];
}

- (void)cancelSearchBar
{
    if (self.searchController.active) {
        
        [self.searchController setActive:NO];
        [self createRefreshControl];
    
        _isSearchMode = NO;
        _searchFileName = @"";
        _dateReadDataSource = nil;
        _searchResultMetadatas = [NSMutableArray new];
        
        [self reloadDatasource];
    }
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete File or Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [self deleteFileOrFolderSuccess:metadataNet]; 
}

- (void)deleteFileOrFolderSuccess:(CCMetadataNet *)metadataNet
{
    [_queueSelector removeObject:metadataNet.selector];
    
    if ([_queueSelector count] == 0) {
        
        [_hud hideHud];
        
        // next
        [_selectedFileIDsMetadatas removeObjectForKey:metadataNet.fileID];
            
        if ([_selectedFileIDsMetadatas count] > 0) {
            
            NSArray *metadatas = [_selectedFileIDsMetadatas allValues];
            [self deleteFileOrFolder:[metadatas objectAtIndex:0] numFile:[_selectedFileIDsMetadatas count] ofFile:_numSelectedFileIDsMetadatas];
            
        } else {
            
            // End Select Table View
            [self tableViewSelect:NO];
            
            // Reload
            if (_isSearchMode)
                [self readFolder:metadataNet.serverUrl];
            else
                [self reloadDatasource:metadataNet.serverUrl];
        }
    }
}

- (void)deleteFileOrFolder:(tableMetadata *)metadata numFile:(NSInteger)numFile ofFile:(NSInteger)ofFile
{
    if (metadata.cryptated) {
        [_queueSelector addObject:selectorDeleteCrypto];
        [_queueSelector addObject:selectorDeletePlist];
    } else {
        [_queueSelector addObject:selectorDelete];
    }
    
    [[CCActions sharedInstance] deleteFileOrFolder:metadata delegate:self];
        
    [_hud visibleHudTitle:[NSString stringWithFormat:NSLocalizedString(@"_delete_file_n_", nil), ofFile - numFile + 1, ofFile] mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)deleteFile
{
    if (_isSelectedMode && [_selectedFileIDsMetadatas count] == 0)
        return;
    
    [_queueSelector removeAllObjects];
    
    if ([_selectedFileIDsMetadatas count] > 0) {
            
        _numSelectedFileIDsMetadatas = [_selectedFileIDsMetadatas count];
        NSArray *metadatas = [_selectedFileIDsMetadatas allValues];
        [self deleteFileOrFolder:[metadatas objectAtIndex:0] numFile:[_selectedFileIDsMetadatas count] ofFile:_numSelectedFileIDsMetadatas];
        
    } else {
        
        _numSelectedFileIDsMetadatas = 1;
        [self deleteFileOrFolder:_metadata numFile:1 ofFile:_numSelectedFileIDsMetadatas];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Rename / Move =====
#pragma --------------------------------------------------------------------------------------------

- (void)renameSuccess:(CCMetadataNet *)metadataNet
{
    [self readFolder:metadataNet.serverUrl];
}

- (void)renameFile:(NSArray *)arguments
{
    tableMetadata* metadata = [arguments objectAtIndex:0];
    NSString *fileName = [arguments objectAtIndex:1];
    
    [[CCActions sharedInstance] renameFileOrFolder:metadata fileName:fileName delegate:self];
}

- (void)renameNote:(NSArray *)arguments
{
    tableMetadata* metadata = [arguments objectAtIndex:0];
    NSString *fileName = [arguments objectAtIndex:1];
    
    CCTemplates *templates = [[CCTemplates alloc] init];
    
    NSMutableDictionary *field = [[CCCrypto sharedManager] getDictionaryEncrypted:metadata.fileName uuid:metadata.uuid isLocal:NO directoryUser:app.directoryUser];
    NSString *fileNameModel = [templates salvaNote:[field objectForKey:@"note"] titolo:fileName fileName:metadata.fileName uuid:metadata.uuid];
    
    if (fileNameModel) {
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionUploadTemplate;
        metadataNet.fileName = [CCUtility trasformedFileNamePlistInCrypto:fileNameModel];
        metadataNet.fileNamePrint = fileName;
        metadataNet.etag = metadata.etag;
        metadataNet.serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
        metadataNet.session = k_upload_session_foreground;
        metadataNet.taskStatus = k_taskStatusResume;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
}

- (void)renameMoveFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    if ([metadataNet.selector isEqualToString:selectorMove]) {
        
        [_hud hideHud];
    
        if (message)
            [app messageNotification:@"_move_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
                
        // End Select Table View
        [self tableViewSelect:NO];
        
        // reload Datasource
        if ([metadataNet.selectorPost isEqualToString:selectorReadFolderForced] || _isSearchMode)
            [self readFolder:metadataNet.serverUrl];
        else
            [self reloadDatasource];
    }
}

- (void)moveSuccess:(CCMetadataNet *)metadataNet
{
    [_queueSelector removeObject:metadataNet.selector];
    
    if ([_queueSelector count] == 0) {
    
        [_hud hideHud];
        
        NSString *fileName = [CCUtility trasformedFileNameCryptoInPlist:metadataNet.fileName];
        NSString *directoryID = metadataNet.directoryID;
        NSString *directoryIDTo = metadataNet.directoryIDTo;
        NSString *serverUrlTo = [[NCManageDatabase sharedInstance] getServerUrl:directoryIDTo];

        // FILE -> Metadata
        if (metadataNet.directory == NO)
            [[NCManageDatabase sharedInstance] moveMetadataWithFileName:fileName directoryID:directoryID directoryIDTo:directoryIDTo];
    
        // DIRECTORY ->  Directory - CCMetadata
        if (metadataNet.directory == YES) {
        
            // delete all dir / subdir
            [[NCManageDatabase sharedInstance] deleteDirectoryAndSubDirectoryWithServerUrl:[CCUtility stringAppendServerUrl:metadataNet.serverUrl addFileName:fileName]];
            
            // move metadata
            [[NCManageDatabase sharedInstance] moveMetadataWithFileName:fileName directoryID:directoryID directoryIDTo:directoryIDTo];
            
            // Add new directory
            NSString *newDirectory = [NSString stringWithFormat:@"%@/%@", serverUrlTo, fileName];
            (void)[[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:newDirectory permissions:@""];
        }
    
        // next
        [_selectedFileIDsMetadatas removeObjectForKey:metadataNet.fileID];
        
        if ([_selectedFileIDsMetadatas count] > 0) {
        
            NSArray *metadatas = [_selectedFileIDsMetadatas allValues];
            
            [self performSelectorOnMainThread:@selector(moveFileOrFolderMetadata:) withObject:@[[metadatas objectAtIndex:0], serverUrlTo, [NSNumber numberWithInteger:[_selectedFileIDsMetadatas count]], [NSNumber numberWithInteger:_numSelectedFileIDsMetadatas]] waitUntilDone:NO];
            
        } else {
            
            // End Select Table View
            [self tableViewSelect:NO];
            
            // reload Datasource
            if ([metadataNet.selectorPost isEqualToString:selectorReadFolderForced] || _isSearchMode)
                [self readFolder:metadataNet.serverUrl];
            else
                [self reloadDatasource];
        }
    }
}

- (void)moveFileOrFolderMetadata:(NSArray *)arguments
{
    tableMetadata *metadata = [arguments objectAtIndex:0];
    NSString *serverUrlTo = [arguments objectAtIndex:1];
    NSInteger numFile = [[arguments objectAtIndex:2] integerValue];
    NSInteger ofFile = [[arguments objectAtIndex:3] integerValue];
    
    // Plain
    if (metadata.cryptated == NO) {
            
        OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:app.activeUser withPassword:app.activePassword withUrl:app.activeUrl isCryptoCloudMode:NO];
            
        NSError *error = [ocNetworking readFileSync:[NSString stringWithFormat:@"%@/%@", serverUrlTo, metadata.fileName]];
            
        if(!error) {
                
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    
                UIAlertController * alert= [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_file_already_exists_", nil) preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                }];
                [alert addAction:ok];
                [self presentViewController:alert animated:YES completion:nil];
            });
            
            // End Select Table View
            [self tableViewSelect:NO];
            
            // reload Datasource
            [self readFileReloadFolder];
            
            return;
        }
            
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionMoveFileOrFolder;
        metadataNet.directory = metadata.directory;
        metadataNet.fileID = metadata.fileID;
        metadataNet.directoryID = metadata.directoryID;
        metadataNet.directoryIDTo = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrlTo];
        metadataNet.fileName = metadata.fileName;
        metadataNet.fileNamePrint = metadataNet.fileNamePrint;
        metadataNet.fileNameTo = metadata.fileName;
        metadataNet.etag = metadata.etag;
        metadataNet.selector = selectorMove;
        metadataNet.serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
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
        metadataNet.directoryID = metadata.directoryID;
        metadataNet.directoryIDTo = [[NCManageDatabase sharedInstance] getDirectoryID:serverUrlTo];
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.etag = metadata.etag;
        metadataNet.serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
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
        
    [_hud visibleHudTitle:[NSString stringWithFormat:NSLocalizedString(@"_move_file_n_", nil), ofFile - numFile + 1, ofFile] mode:MBProgressHUDModeIndeterminate color:nil];
}

// DELEGATE : Move
- (void)dismissMove
{
    [self reloadDatasource];

}

// DELEGATE : Move
- (void)moveServerUrlTo:(NSString *)serverUrlTo title:(NSString *)title
{
    [_queueSelector removeAllObjects];
    
    if ([_selectedFileIDsMetadatas count] > 0) {
            
        _numSelectedFileIDsMetadatas = [_selectedFileIDsMetadatas count];
        NSArray *metadatas = [_selectedFileIDsMetadatas allValues];
            
        [self performSelectorOnMainThread:@selector(moveFileOrFolderMetadata:) withObject:@[[metadatas objectAtIndex:0], serverUrlTo, [NSNumber numberWithInteger:[_selectedFileIDsMetadatas count]], [NSNumber numberWithInteger:_numSelectedFileIDsMetadatas]] waitUntilDone:NO];
            
    } else {
        
        _numSelectedFileIDsMetadatas = 1;
        [self performSelectorOnMainThread:@selector(moveFileOrFolderMetadata:) withObject:@[_metadata, serverUrlTo, [NSNumber numberWithInteger:1], [NSNumber numberWithInteger:_numSelectedFileIDsMetadatas]] waitUntilDone:NO];
    }
}

- (void)moveOpenWindow:(NSArray *)indexPaths
{
    if (_isSelectedMode && [_selectedFileIDsMetadatas count] == 0)
        return;
    
    UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMove"];
    
    CCMove *viewController = (CCMove *)navigationController.topViewController;

    viewController.delegate = self;
    viewController.move.title = NSLocalizedString(@"_move_", nil);
    viewController.tintColor = [NCBrandColor sharedInstance].navigationBarText;
    viewController.barTintColor = [NCBrandColor sharedInstance].brand;
    viewController.tintColorTitle = [NCBrandColor sharedInstance].navigationBarText;
    viewController.networkingOperationQueue = app.netQueue;
    
    [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)createFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    if (metadataNet.cryptated == NO) {
        
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadataNet.fileID] clearDateReadDirectoryID:nil];
        [self reloadDatasource];
        
        // We are in directory fail ?
        CCMain *vc = [app.listMainVC objectForKey:[CCUtility stringAppendServerUrl:_serverUrl addFileName:metadataNet.fileName]];
        if (vc)
            [vc.navigationController popViewControllerAnimated:YES];
    }
    
    if (message)
        [app messageNotification:@"_create_folder_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
}

- (void)createFolderSuccess:(CCMetadataNet *)metadataNet
{
    NSString *newDirectory = [NSString stringWithFormat:@"%@/%@", metadataNet.serverUrl, metadataNet.fileName];    
    (void)[[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:newDirectory permissions:@""];
    
    if (metadataNet.cryptated == NO) {
    
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileName = %@ AND directoryID = %@", metadataNet.fileName, metadataNet.directoryID]];
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileName = %@ AND directoryID = %@", metadataNet.fileName, metadataNet.directoryID] clearDateReadDirectoryID:nil];

        metadata.fileID = metadataNet.fileID;
        metadata.date = metadataNet.date;
        metadata.permissions = @"RDNVCK";

        (void)[[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:app.activeUrl serverUrl:_serverUrl];
        
        [self reloadDatasource];
    }
}

- (void)createFolder:(NSString *)fileNameFolder autoUploadDirectory:(BOOL)autoUploadDirectory
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    fileNameFolder = [CCUtility removeForbiddenCharactersServer:fileNameFolder];
    if (![fileNameFolder length]) return;
    
    if (autoUploadDirectory) metadataNet.serverUrl = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:app.activeUrl];
    else  metadataNet.serverUrl = _serverUrl;
    
    metadataNet.action = actionCreateFolder;
    metadataNet.directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];
    if (autoUploadDirectory)
        metadataNet.options = @"folderAutoUpload";
    metadataNet.fileID = [[NSUUID UUID] UUIDString];
    metadataNet.fileName = fileNameFolder;
    metadataNet.selector = selectorCreateFolder;
    metadataNet.serverUrl = _serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
    // Create Directory on metadata
    tableMetadata *metadata = [CCUtility createMetadataWithAccount:app.activeAccount date:[NSDate date] directory:YES fileID:metadataNet.fileID directoryID:metadataNet.directoryID fileName:metadataNet.fileName etag:@"" size:0 status:k_metadataStatusNormal];
    (void)[[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:app.activeUrl serverUrl:_serverUrl];
    
    [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:_serverUrl directoryID:nil];
    [self reloadDatasource];
}

- (void)createFolderEncrypted:(NSString *)fileNameFolder
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    NSString *fileNamePlist;
    
    fileNameFolder = [CCUtility removeForbiddenCharactersServer:fileNameFolder];
    if (![fileNameFolder length]) return;
    
    NSString *title = [AESCrypt encrypt:fileNameFolder password:[[CCCrypto sharedManager] getKeyPasscode:[CCUtility getUUID]]];

    fileNamePlist =  [[CCCrypto sharedManager] createFilenameEncryptor:fileNameFolder uuid:[CCUtility getUUID]];
    
    [[CCCrypto sharedManager] createFilePlist:[NSTemporaryDirectory() stringByAppendingString:fileNamePlist] title:title len:0 directory:true uuid:[CCUtility getUUID] nameCurrentDevice:[CCUtility getNameCurrentDevice] icon:@""];
    
    // Create folder
    metadataNet.action = actionCreateFolder;
    metadataNet.cryptated = YES;
    metadataNet.fileID = [[NSUUID UUID] UUIDString];
    metadataNet.fileName = fileNamePlist;
    metadataNet.priority = NSOperationQueuePriorityVeryHigh;
    metadataNet.selector = selectorCreateFolder;
    metadataNet.serverUrl = _serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    // upload plist file
    metadataNet.action = actionUploadOnlyPlist;
    metadataNet.cryptated = YES;
    metadataNet.fileID = [[NSUUID UUID] UUIDString];
    metadataNet.fileName = [fileNamePlist stringByAppendingString:@".plist"];
    metadataNet.priority = NSOperationQueuePriorityVeryLow;
    metadataNet.selectorPost = selectorReadFolderForced;
    metadataNet.serverUrl = _serverUrl;
    metadataNet.session = k_upload_session_foreground;
    metadataNet.taskStatus = k_taskStatusResume;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  Encrypted / Decrypted Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)encyptedDecryptedFolder
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    
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
        metadataNet.serverUrl = serverUrl;
        metadataNet.serverUrlTo = serverUrl;
        
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
        
        // Create File Plist
        NSString *fileNameCrypto = [[CCCrypto sharedManager] createFileDirectoryPlist:_metadata];
        
        //-------------------------- RENAME -------------------------------------------//
        
        metadataNet.action = actionMoveFileOrFolder;
        metadataNet.fileID = _metadata.fileID;
        metadataNet.fileName = _metadata.fileName;
        metadataNet.fileNamePrint = _metadata.fileNamePrint;
        metadataNet.fileNameTo = fileNameCrypto;
        metadataNet.priority = NSOperationQueuePriorityVeryHigh;
        metadataNet.selector = selectorRename;
        metadataNet.serverUrl = serverUrl;
        metadataNet.serverUrlTo = serverUrl;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
        
        //-------------------------- UPLOAD -------------------------------------------//
        
        metadataNet.action = actionUploadOnlyPlist;
        metadataNet.fileName = [fileNameCrypto stringByAppendingString:@".plist"];
        metadataNet.priority = NSOperationQueuePriorityVeryLow;
        metadataNet.selectorPost = selectorReadFolderForced;
        metadataNet.serverUrl = serverUrl;
        metadataNet.session = k_upload_session_foreground;
        metadataNet.taskStatus = k_taskStatusResume;
        
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
    
    for (tableMetadata *metadata in selectedMetadatas) {
        if (metadata.cryptated == NO && metadata.directory == NO)
            [metadatas addObject:metadata];
    }
    
    if ([metadatas count] > 0) {
        
        NSLog(@"[LOG] Start encrypted selected files ...");
    
        for (tableMetadata* metadata in metadatas) {
            
            NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
            
            [[CCNetworking sharedNetworking] downloadFile:metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorEncryptFile selectorPost:nil session:k_download_session taskStatus: k_taskStatusResume delegate:self];
        }
    }
    
    [self tableViewSelect:NO];
}

- (void)decryptedSelectedFiles
{
    NSMutableArray *metadatas = [[NSMutableArray alloc] init];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    for (tableMetadata *metadata in selectedMetadatas) {
        if (metadata.cryptated == YES && metadata.directory == NO && [metadata.model length] == 0)
            [metadatas addObject:metadata];
    }
    
    if ([metadatas count] > 0) {
        
        NSLog(@"[LOG] Start decrypted selected files ...");
        
        for (tableMetadata* metadata in metadatas) {
            
            NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
            
            [[CCNetworking sharedNetworking] downloadFile:metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorDecryptFile selectorPost:nil session:k_download_session taskStatus: k_taskStatusResume delegate:self];
        }
    }
    
    [self tableViewSelect:NO];
}

- (void)cmdEncryptedDecryptedFile
{
    NSString *selector;
    
    if (_metadata.cryptated == YES) selector = selectorDecryptFile;
    if (_metadata.cryptated == NO) selector = selectorEncryptFile;
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    
    [[CCNetworking sharedNetworking] downloadFile:_metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selector selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
}

- (void)encryptedFile:(tableMetadata *)metadata
{
    NSString *fileNameFrom = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID];
    NSString *fileNameTo = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileNamePrint];
    [[NSFileManager defaultManager] copyItemAtPath:fileNameFrom toPath:fileNameTo error:nil];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileNameTo]) {
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
                
        dispatch_async(dispatch_get_main_queue(), ^{
            [[CCNetworking sharedNetworking] uploadFile:metadata.fileName serverUrl:serverUrl cryptated:YES onlyPlist:NO session:k_upload_session taskStatus:k_taskStatusResume selector:nil selectorPost:nil errorCode:0 delegate:nil];
            [self performSelector:@selector(reloadDatasource) withObject:nil];
        });
        
    } else {
            
        [app messageNotification:@"_encrypted_selected_files_" description:@"_file_not_present_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
    }
}

- (void)decryptedFile:(tableMetadata *)metadata
{
    NSString *fileNameFrom = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID];
    NSString *fileNameTo = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileNamePrint];
        
    [[NSFileManager defaultManager] copyItemAtPath:fileNameFrom toPath:fileNameTo error:nil];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileNameTo]) {
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[CCNetworking sharedNetworking] uploadFile:metadata.fileNamePrint serverUrl:serverUrl cryptated:NO onlyPlist:NO session:k_upload_session taskStatus:k_taskStatusResume selector:nil selectorPost:nil errorCode:0 delegate:nil];
            [self performSelector:@selector(reloadDatasource) withObject:nil];
        });
        
    } else {
            
        [app messageNotification:@"_decrypted_selected_files_" description:@"_file_not_present_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)triggerProgressTask:(NSNotification *)notification
{
    NSDictionary *dict = notification.userInfo;
    NSString *fileID = [dict valueForKey:@"fileID"];
    NSString *serverUrl = [dict valueForKey:@"serverUrl"];
    BOOL cryptated = [[dict valueForKey:@"cryptated"] boolValue];
    float progress = [[dict valueForKey:@"progress"] floatValue];
    
    // CCProgress
    if (progress == 0)
        [self.navigationController cancelCCProgress];
    else
        [self.navigationController setCCProgressPercentage:progress*100 andTintColor: [NCBrandColor sharedInstance].navigationBarProgress];
    
    // Check
    if (!fileID)
        return;
    
    [app.listProgressMetadata setObject:[NSNumber numberWithFloat:progress] forKey:fileID];
    
    if (![serverUrl isEqualToString:_serverUrl])
        return;
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:fileID];
    
    if ([self indexPathIsValid:indexPath]) {
        
        CCTransfersCell *cell = (CCTransfersCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        
        if (cryptated) cell.progressView.progressTintColor = [NCBrandColor sharedInstance].cryptocloud;
        else cell.progressView.progressTintColor = [UIColor blackColor];
        
        cell.progressView.hidden = NO;
        [cell.progressView setProgress:progress];
    }
}

- (void)reloadTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if ([self indexPathIsValid:indexPath]) {
        
        tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
        
        if (metadata)
            [self reloadTaskButton:metadata];
    }
}

- (void)reloadTaskButton:(tableMetadata *)metadata
{
    NSURLSession *session = [[CCNetworking sharedNetworking] getSessionfromSessionDescription:metadata.session];
    __block NSURLSessionTask *findTask;
    
    NSInteger sessionTaskIdentifier = metadata.sessionTaskIdentifier;
    NSInteger sessionTaskIdentifierPlist = metadata.sessionTaskIdentifierPlist;
    NSString *fileID = metadata.fileID;
    
    // DOWNLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"download"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionUploadTask *task in downloadTasks)
                if (task.taskIdentifier == sessionTaskIdentifier || task.taskIdentifier == sessionTaskIdentifierPlist) {
                    findTask = task;
                    [app.listChangeTask setObject:@"reloadDownload" forKey:fileID];
                    [task cancel];
                }
            
            if (!findTask) {
                
                [app.listChangeTask setObject:@"reloadDownload" forKey:fileID];
                NSArray *object = [[NSArray alloc] initWithObjects:session, fileID, findTask, nil];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
            }
        }];
    }

    // UPLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"upload"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionUploadTask *task in uploadTasks)
                if (task.taskIdentifier == sessionTaskIdentifier || task.taskIdentifier == sessionTaskIdentifierPlist) {
                    findTask = task;
                    [app.listChangeTask setObject:@"reloadUpload" forKey:fileID];
                    [task cancel];
                }
            
            if (!findTask) {
                
                [app.listChangeTask setObject:@"reloadUpload" forKey:fileID];
                NSArray *object = [[NSArray alloc] initWithObjects:session, fileID, findTask, nil];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
            }
        }];
    }
}

- (void)cancelTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if ([self indexPathIsValid:indexPath]) {
        
        tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
        
        if (metadata)
            [self cancelTaskButton:metadata reloadTable:YES];
    }
}

- (void)cancelTaskButton:(tableMetadata *)metadata reloadTable:(BOOL)reloadTable
{    
    NSURLSession *session = [[CCNetworking sharedNetworking] getSessionfromSessionDescription:metadata.session];
    __block NSURLSessionTask *findTask;
    
    NSInteger sessionTaskIdentifier = metadata.sessionTaskIdentifier;
    NSInteger sessionTaskIdentifierPlist = metadata.sessionTaskIdentifierPlist;
    NSString *fileID = metadata.fileID;
    
    // DOWNLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"download"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionTask *task in downloadTasks)
                if (task.taskIdentifier == sessionTaskIdentifier || task.taskIdentifier == sessionTaskIdentifierPlist) {
                    findTask = task;
                    [app.listChangeTask setObject:@"cancelDownload" forKey:fileID];
                    [task cancel];
                }
            
            if (!findTask) {
                
                [app.listChangeTask setObject:@"cancelDownload" forKey:fileID];
                NSArray *object = [[NSArray alloc] initWithObjects:session, fileID, findTask, nil];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
            }
        }];
    }

    // UPLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"upload"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionUploadTask *task in uploadTasks)
                if (task.taskIdentifier == sessionTaskIdentifier ||  task.taskIdentifier == sessionTaskIdentifierPlist) {
                    findTask = task;
                    [app.listChangeTask setObject:@"cancelUpload" forKey:fileID];
                    [task cancel];
                }
            
            if (!findTask) {
                
                [app.listChangeTask setObject:@"cancelUpload" forKey:fileID];
                NSArray *object = [[NSArray alloc] initWithObjects:session, fileID, findTask, nil];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
            }
        }];
    }
}

- (void)stopTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if ([self indexPathIsValid:indexPath]) {
        
        tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
        
        if (metadata)
            [self stopTaskButton:metadata];
    }
}

- (void)stopTaskButton:(tableMetadata *)metadata
{
    NSURLSession *session = [[CCNetworking sharedNetworking] getSessionfromSessionDescription:metadata.session];
    __block NSURLSessionTask *findTask;

    NSInteger sessionTaskIdentifier = metadata.sessionTaskIdentifier;
    NSInteger sessionTaskIdentifierPlist = metadata.sessionTaskIdentifierPlist;
    NSString *fileID = metadata.fileID;
    
    // UPLOAD
    if ([metadata.session length] > 0 && [metadata.session containsString:@"upload"]) {
        
        [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
            
            for (NSURLSessionUploadTask *task in uploadTasks)
                if (task.taskIdentifier == sessionTaskIdentifier || task.taskIdentifier == sessionTaskIdentifierPlist) {
                    [app.listChangeTask setObject:@"stopUpload" forKey:fileID];
                    findTask = task;
                    [task cancel];
                }
            
            if (!findTask) {
                
                [app.listChangeTask setObject:@"stopUpload" forKey:fileID];
                NSArray *object = [[NSArray alloc] initWithObjects:session, fileID, findTask, nil];
                [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_networkingSessionNotification object:object];
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
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // change account ?
    tableAccount *record = [[NCManageDatabase sharedInstance] getAccountActive];
    if([record.account isEqualToString:metadataNet.account] == NO)
        return;
    
    NSArray *result = [[NCManageDatabase sharedInstance] updateShare:items activeUrl:appDelegate.activeUrl];
    if (result) {
        appDelegate.sharesLink = result[0];
        appDelegate.sharesUserAndGroup = result[1];
    }
    
    // Notify Shares View
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"SharesReloadDatasource" object:nil userInfo:nil];
    
    if (openWindow) {
            
        if (_shareOC) {
                
            [_shareOC reloadData];
                
        } else {
            
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadataNet.fileID]];
            
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

    [self tableViewReloadData];
}

- (void)shareFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [_hud hideHud];
    
    [app messageNotification:@"_share_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];

    if (_shareOC)
        [_shareOC reloadData];
    
    [self tableViewReloadData];
    
    if (errorCode == 401)
        [self changePasswordAccount];
}

- (void)share:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionShare;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:serverUrl activeUrl:app.activeUrl];
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.password = password;
    metadataNet.selector = selectorShare;
    metadataNet.serverUrl = serverUrl;
        
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];

    [_hud visibleHudTitle:NSLocalizedString(@"_creating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)unShareSuccess:(CCMetadataNet *)metadataNet
{
    [_hud hideHud];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    // rimuoviamo la condivisione da db
    NSArray *result = [[NCManageDatabase sharedInstance] unShare:metadataNet.share fileName:metadataNet.fileName serverUrl:metadataNet.serverUrl sharesLink:appDelegate.sharesLink sharesUserAndGroup:appDelegate.sharesUserAndGroup];
    
    if (result) {
        appDelegate.sharesLink = result[0];
        appDelegate.sharesUserAndGroup = result[1];
    }
    
    if (_shareOC)
        [_shareOC reloadData];
    
    [self tableViewReloadData];
}

- (void)unShare:(NSString *)share metadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl
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

- (void)updateShare:(NSString *)share metadata:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password expirationTime:(NSString *)expirationTime permission:(NSInteger)permission
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionUpdateShare;
    metadataNet.fileID = metadata.fileID;
    metadataNet.expirationTime = expirationTime;
    metadataNet.password = password;
    metadataNet.selector = selectorUpdateShare;
    metadataNet.serverUrl = serverUrl;
    metadataNet.share = share;
    metadataNet.sharePermission = permission;
        
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];

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
    
    [app messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
}

- (void)getUserAndGroup:(NSString *)find
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionGetUserAndGroup;
    metadataNet.options = find;
    metadataNet.selector = selectorGetUserAndGroup;
        
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleIndeterminateHud];
}

- (void)shareUserAndGroup:(NSString *)user shareeType:(NSInteger)shareeType permission:(NSInteger)permission metadata:(tableMetadata *)metadata directoryID:(NSString *)directoryID serverUrl:(NSString *)serverUrl
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];

    metadataNet.action = actionShareWith;
    metadataNet.fileID = metadata.fileID;
    metadataNet.directoryID = directoryID;
    metadataNet.fileName = [CCUtility returnFileNamePathFromFileName:metadata.fileName serverUrl:serverUrl activeUrl:app.activeUrl];
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.serverUrl = serverUrl;
    metadataNet.selector = selectorShare;
    metadataNet.share = user;
    metadataNet.shareeType = shareeType;
    metadataNet.sharePermission = permission;

    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleHudTitle:NSLocalizedString(@"_creating_sharing_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)openWindowShare:(tableMetadata *)metadata
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    metadataNet.action = actionReadShareServer;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = metadata.fileName;
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.selector = selectorOpenWindowShare;
    metadataNet.serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    
    [_hud visibleIndeterminateHud];
}

- (void)tapActionShared:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (metadata)
        [self openWindowShare:metadata];
}

- (void)tapActionConnectionMounted:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
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

- (void)settingFavoriteSuccess:(CCMetadataNet *)metadataNet
{
    _dateReadDataSource = nil;
    
    [[NCManageDatabase sharedInstance] setMetadataFavoriteWithFileID:metadataNet.fileID favorite:[metadataNet.options boolValue]];
    
    if (_isSearchMode)
        [self readFolder:metadataNet.serverUrl];
    else
        [self reloadDatasource:metadataNet.serverUrl];
    
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadataNet.fileID]];
    
    if (metadata.directory && metadata.favorite) {
        
        NSString *dir = [CCUtility stringAppendServerUrl:metadataNet.serverUrl addFileName:metadata.fileNameData];
        
        [app.activeFavorites addFavoriteFolder:dir];
    }
}

- (void)settingFavoriteFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
}

- (void)addFavorite:(tableMetadata *)metadata
{
    if (metadata.directory) {
        
        [[CCActions sharedInstance] settingFavorite:metadata favorite:YES delegate:self];
        
    } else {
    
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
        
        [[CCNetworking sharedNetworking] downloadFile:metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorAddFavorite selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
    }
}

- (void)removeFavorite:(tableMetadata *)metadata
{
    [[CCActions sharedInstance] settingFavorite:metadata favorite:NO delegate:self];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Local =====
#pragma --------------------------------------------------------------------------------------------

- (void)addLocal:(tableMetadata *)metadata
{
    if (metadata.errorPasscode || !metadata.uuid) return;
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];

    if ([metadata.type isEqualToString: k_metadataType_file])
        [[CCNetworking sharedNetworking] downloadFile:metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorAddLocal selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
    
    if ([metadata.type isEqualToString: k_metadataType_template]) {
        
        [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileName] toPath:[NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryLocal], metadata.fileName]];
        
        [app messageNotification:@"_add_local_" description:@"_file_saved_local_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess errorCode:0];
    }
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadata.fileID];
    
    if ([self indexPathIsValid:indexPath])
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Open in... =====
#pragma --------------------------------------------------------------------------------------------

- (void)openIn:(tableMetadata *)metadata
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];

    [[CCNetworking sharedNetworking] downloadFile:metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorOpenIn selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadata.fileID];
    if ([self indexPathIsValid:indexPath])
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Remove Local File =====
#pragma --------------------------------------------------------------------------------------------

- (void)removeLocalFile:(tableMetadata *)metadata
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    
    [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];
    
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] error:nil];
    
    [self reloadDatasource:serverUrl];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Order Table & GroupBy & DirectoryOnTop =====
#pragma --------------------------------------------------------------------------------------------

- (void)orderTable:(NSString *)order
{
    [CCUtility setOrderSettings:order];
    
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
}

- (void)ascendingTable:(BOOL)ascending
{
    [CCUtility setAscendingSettings:ascending];
    
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
}

- (void)directoryOnTop:(BOOL)directoryOnTop
{
    [CCUtility setDirectoryOnTop:directoryOnTop];
    
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
}

- (void)tableGroupBy:(NSString *)groupBy
{
    [CCUtility setGroupBySettings:groupBy];
    
    // Clear data-read of DataSource
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"clearDateReadDataSource" object:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Menu LOGO ====
#pragma --------------------------------------------------------------------------------------------

- (void)menuLogo
{
    if (app.reSelectMenu.isOpen || app.reMainMenu.isOpen)
        return;
    
    // Brand
    if ([NCBrandOptions sharedInstance].disable_multiaccount)
        return;
    
    if ([app.netQueue operationCount] > 0 || [app.netQueueDownload operationCount] > 0 || [app.netQueueDownloadWWan operationCount] > 0 || [app.netQueueUpload operationCount] > 0 || [app.netQueueUploadWWan operationCount] > 0 || [[NCManageDatabase sharedInstance] countQueueUploadWithSession:nil] > 0) {
        
        [app messageNotification:@"_transfers_in_queue_" description:nil visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
        return;
    }
    
    NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
    
    NSMutableArray *menuArray = [NSMutableArray new];
    
    for (NSString *account in listAccount) {
     
        if ([account isEqualToString:app.activeAccount]) continue;
        
        CCMenuItem *item = [[CCMenuItem alloc] init];
        
        item.title = [account stringByTruncatingToWidth:self.view.bounds.size.width - 100 withFont:[UIFont systemFontOfSize:12.0] atEnd:YES];
        item.argument = account;
        item.image = [UIImage imageNamed:@"menuLogoUser"];
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
    
    NSInteger originY = 60;

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
    
    CGRect rect = self.view.frame;
    rect.origin.y = rect.origin.y + originY;
    rect.size.height = rect.size.height - originY;
    
    [CCMenuAccount setTitleFont:[UIFont systemFontOfSize:12.0]];
    [CCMenuAccount showMenuInView:self.navigationController.view fromRect:rect menuItems:menuArray withOptions:options];    
}

- (void)changeDefaultAccount:(CCMenuItem *)sender
{
    [_ImageTitleHomeCryptoCloud setUserInteractionEnabled:NO];
    
    // STOP, erase all in  queue networking
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:k_taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
        tableAccount *tableAccount = [[NCManageDatabase sharedInstance] setAccountActive:[sender argument]];
        if (tableAccount)
            [app settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activePassword:tableAccount.password];
    
        // go to home sweet home
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil];
        
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
    
    // ITEM SELECT ----------------------------------------------------------------------------------------------------
    
    app.selezionaItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_select_", nil)subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"seleziona"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
            if ([_sectionDataSource.allRecordsDataSource count] > 0) {
                [self tableViewSelect:YES];
            }
    }];

    // ITEM ORDER ----------------------------------------------------------------------------------------------------
    
    ordinamento = _directoryOrder;
    if ([ordinamento isEqualToString:@"fileName"]) {
        
        image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuOrdeyByDate"] color:[NCBrandColor sharedInstance].brand];
        titoloNuovo = NSLocalizedString(@"_order_by_date_", nil);
        titoloAttuale = NSLocalizedString(@"_current_order_name_", nil);
        nuovoOrdinamento = @"date";
    }
    
    if ([ordinamento isEqualToString:@"date"]) {
        
        image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuOrderByFileName"] color:[NCBrandColor sharedInstance].brand];
        titoloNuovo = NSLocalizedString(@"_order_by_name_", nil);
        titoloAttuale = NSLocalizedString(@"_current_order_date_", nil);
        nuovoOrdinamento = @"fileName";
    }
    
    app.ordinaItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:titoloAttuale image:image highlightedImage:nil action:^(REMenuItem *item) {
        [self orderTable:nuovoOrdinamento];
    }];
    
    // ITEM ASCENDING -----------------------------------------------------------------------------------------------------
    
    ascendente = [CCUtility getAscendingSettings];
    
    if (ascendente)  {
        
        image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuOrdinamentoDiscendente"] color:[NCBrandColor sharedInstance].brand];
        titoloNuovo = NSLocalizedString(@"_sort_descending_", nil);
        titoloAttuale = NSLocalizedString(@"_current_sort_ascending_", nil);
        nuovoAscendente = false;
    }
    
    if (!ascendente) {
        
        image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuOrdinamentoAscendente"] color:[NCBrandColor sharedInstance].brand];
        titoloNuovo = NSLocalizedString(@"_sort_ascending_", nil);
        titoloAttuale = NSLocalizedString(@"_current_sort_descending_", nil);
        nuovoAscendente = true;
    }
    
    app.ascendenteItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:titoloAttuale image:image highlightedImage:nil action:^(REMenuItem *item) {
        [self ascendingTable:nuovoAscendente];
    }];
    
    
    // ITEM ALPHABETIC -----------------------------------------------------------------------------------------------------
    
    if ([groupBy isEqualToString:@"alphabetic"])  { titoloNuovo = NSLocalizedString(@"_group_alphabetic_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_group_alphabetic_no_", nil); }
    
    app.alphabeticItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuGroupByAlphabetic"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
            if ([groupBy isEqualToString:@"alphabetic"]) [self tableGroupBy:@"none"];
            else [self tableGroupBy:@"alphabetic"];
    }];
    
    // ITEM TYPEFILE -------------------------------------------------------------------------------------------------------
    
    if ([groupBy isEqualToString:@"typefile"])  { titoloNuovo = NSLocalizedString(@"_group_typefile_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_group_typefile_no_", nil); }
    
    app.typefileItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuGroupByTypeFile"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
            if ([groupBy isEqualToString:@"typefile"]) [self tableGroupBy:@"none"];
            else [self tableGroupBy:@"typefile"];
    }];
   

    // ITEM DATE -------------------------------------------------------------------------------------------------------
    
    if ([groupBy isEqualToString:@"date"])  { titoloNuovo = NSLocalizedString(@"_group_date_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_group_date_no_", nil); }
    
    app.dateItem = [[REMenuItem alloc] initWithTitle:titoloNuovo   subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"MenuGroupByDate"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
            if ([groupBy isEqualToString:@"date"]) [self tableGroupBy:@"none"];
            else [self tableGroupBy:@"date"];
    }];
    
    // ITEM DIRECTORY ON TOP ------------------------------------------------------------------------------------------------
    
    if ([CCUtility getDirectoryOnTop])  { titoloNuovo = NSLocalizedString(@"_directory_on_top_yes_", nil); }
    else { titoloNuovo = NSLocalizedString(@"_directory_on_top_no_", nil); }
    
    app.directoryOnTopItem = [[REMenuItem alloc] initWithTitle:titoloNuovo subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"menuDirectoryOnTop"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
            if ([CCUtility getDirectoryOnTop]) [self directoryOnTop:NO];
            else [self directoryOnTop:YES];
    }];
    

    // REMENU --------------------------------------------------------------------------------------------------------------

    app.reMainMenu = [[REMenu alloc] initWithItems:@[app.selezionaItem, app.ordinaItem, app.ascendenteItem, app.alphabeticItem, app.typefileItem, app.dateItem, app.directoryOnTopItem]];
    
    app.reMainMenu.imageOffset = CGSizeMake(5, -1);
    
    app.reMainMenu.separatorOffset = CGSizeMake(50.0, 0.0);
    app.reMainMenu.imageOffset = CGSizeMake(0, 0);
    app.reMainMenu.waitUntilAnimationIsComplete = NO;
    
    app.reMainMenu.separatorHeight = 0.5;
    app.reMainMenu.separatorColor = [NCBrandColor sharedInstance].seperator;
    
    app.reMainMenu.backgroundColor = [NCBrandColor sharedInstance].menuBackground;
    app.reMainMenu.textColor = [UIColor blackColor];
    app.reMainMenu.textAlignment = NSTextAlignmentLeft;
    app.reMainMenu.textShadowColor = nil;
    app.reMainMenu.textOffset = CGSizeMake(50, 0.0);
    app.reMainMenu.font = [UIFont systemFontOfSize:14.0];
    
    app.reMainMenu.highlightedBackgroundColor = [[NCBrandColor sharedInstance] getColorSelectBackgrond];
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
        [_reMenuBackgroundView removeGestureRecognizer:_singleFingerTap];
    }];
}

- (void)toggleReMainMenu
{
    if (app.reMainMenu.isOpen) {
        
        [app.reMainMenu close];
        
    } else {
        
        [self createReMainMenu];
        [app.reMainMenu showFromNavigationController:self.navigationController];
        
        // Backgroun reMenu & (Gesture)
        [self createReMenuBackgroundView:app.reMainMenu];
        _singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleReMainMenu)];
        [_reMenuBackgroundView addGestureRecognizer:_singleFingerTap];
    }
}

- (void)createReSelectMenu
{
    // ITEM DELETE ------------------------------------------------------------------------------------------------------
    
    app.deleteItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_delete_selected_files_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"deleteSelectedFiles"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
            [self deleteFile];
    }];
    
    // ITEM MOVE ------------------------------------------------------------------------------------------------------
    
    app.moveItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_move_selected_files_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"moveSelectedFiles"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
            [self moveOpenWindow:[self.tableView indexPathsForSelectedRows]];
    }];
    
    if (app.isCryptoCloudMode) {
    
        // ITEM ENCRYPTED ------------------------------------------------------------------------------------------------------
    
        app.encryptItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_encrypted_selected_files_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"encryptedSelectedFiles"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
                [self performSelector:@selector(encryptedSelectedFiles) withObject:nil];
        }];
    
        // ITEM DECRYPTED ----------------------------------------------------------------------------------------------------
    
        app.decryptItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_decrypted_selected_files_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"decryptedSelectedFiles"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
                [self performSelector:@selector(decryptedSelectedFiles) withObject:nil];
        }];
    }
    
    // ITEM DOWNLOAD ----------------------------------------------------------------------------------------------------
    
    app.downloadItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_download_selected_files_folders_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"downloadSelectedFiles"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
            [self downloadSelectedFilesFolders];
    }];
    
    // ITEM SAVE IMAGE & VIDEO -------------------------------------------------------------------------------------------
    
    app.saveItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"_save_selected_files_", nil) subtitle:@"" image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"saveSelectedFiles"] color:[NCBrandColor sharedInstance].brand] highlightedImage:nil action:^(REMenuItem *item) {
            [self saveSelectedFiles];
    }];

    // REMENU --------------------------------------------------------------------------------------------------------------
    
    if (app.isCryptoCloudMode) {
        app.reSelectMenu = [[REMenu alloc] initWithItems:@[app.deleteItem,app.moveItem, app.encryptItem, app.decryptItem, app.downloadItem, app.saveItem]];
    } else {
        app.reSelectMenu = [[REMenu alloc] initWithItems:@[app.deleteItem,app.moveItem, app.downloadItem, app.saveItem]];
    }
    
    app.reSelectMenu.imageOffset = CGSizeMake(5, -1);
    
    app.reSelectMenu.separatorOffset = CGSizeMake(50.0, 0.0);
    app.reSelectMenu.imageOffset = CGSizeMake(0, 0);
    app.reSelectMenu.waitUntilAnimationIsComplete = NO;
    
    app.reSelectMenu.separatorHeight = 0.5;
    app.reSelectMenu.separatorColor = [NCBrandColor sharedInstance].seperator;
    
    app.reSelectMenu.backgroundColor = [NCBrandColor sharedInstance].menuBackground;
    app.reSelectMenu.textColor = [UIColor blackColor];
    app.reSelectMenu.textAlignment = NSTextAlignmentLeft;
    app.reSelectMenu.textShadowColor = nil;
    app.reSelectMenu.textOffset = CGSizeMake(50, 0.0);
    app.reSelectMenu.font = [UIFont systemFontOfSize:14.0];
    
    app.reSelectMenu.highlightedBackgroundColor = [[NCBrandColor sharedInstance] getColorSelectBackgrond];
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
        
        [self createReSelectMenu];
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
        
        if ([self indexPathIsValid:indexPath])
            _metadata = [self getMetadataFromSectionDataSource:indexPath];
        else
            _metadata = nil;
        
        [self becomeFirstResponder];
        
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        
        UIMenuItem *copyFileItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_copy_file_", nil) action:@selector(copyFile:)];
        UIMenuItem *copyFilesItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_copy_files_", nil) action:@selector(copyFiles:)];

        UIMenuItem *openinFileItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_open_in_", nil) action:@selector(openinFile:)];
        
        UIMenuItem *pasteFileItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_file_", nil) action:@selector(pasteFile:)];
        UIMenuItem *pasteFileEncryptedItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_file_encrypted_", nil) action:@selector(pasteFileEncrypted:)];
        
        UIMenuItem *pasteFilesItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_files_", nil) action:@selector(pasteFiles:)];
        UIMenuItem *pasteFilesEncryptedItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_files_encrypted_", nil) action:@selector(pasteFilesEncrypted:)];
        
        if (app.isCryptoCloudMode)
            [menuController setMenuItems:[NSArray arrayWithObjects:copyFileItem, copyFilesItem, openinFileItem, pasteFileItem, pasteFilesItem, pasteFileEncryptedItem, pasteFilesEncryptedItem, nil]];
        else
            [menuController setMenuItems:[NSArray arrayWithObjects:copyFileItem, copyFilesItem, openinFileItem, pasteFileItem, pasteFilesItem, nil]];

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
    // For copy file, copy files, Open in ... :
    //
    // NO Directory
    // NO Error Passcode
    // NO In Session mode (download/upload)
    // NO Template
    
    if (@selector(copyFile:) == action || @selector(openinFile:) == action) {
        
        if (_isSelectedMode == NO && _metadata && !_metadata.directory && !_metadata.errorPasscode && [_metadata.session length] == 0 && ![_metadata.typeFile isEqualToString: k_metadataTypeFile_template])  {
            
            // NO Cryptated with Title lenght = 0
            if (!_metadata.cryptated || (_metadata.cryptated && _metadata.title.length > 0))
                return YES;
        }
        return NO;
    }
    
    if (@selector(copyFiles:) == action) {
        
        if (_isSelectedMode) {
            
            NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
            
            for (tableMetadata *metadata in selectedMetadatas) {
                
                if (!metadata.directory && !metadata.errorPasscode && metadata.session.length == 0 && ![metadata.typeFile isEqualToString: k_metadataTypeFile_template])  {
                    
                    // NO Cryptated with Title lenght = 0
                    if (!metadata.cryptated || (metadata.cryptated && metadata.title.length > 0))
                        return YES;
                }
            }
        }
        return NO;
    }

    if (@selector(pasteFile:) == action || @selector(pasteFileEncrypted:) == action) {
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray *items = [pasteboard items];
        
        if ([items count] == 1) {
            
            // Value : (NSData) fileID
            
            NSDictionary *dic = [items objectAtIndex:0];
            
            NSData *dataFileID = [dic objectForKey: k_metadataKeyedUnarchiver];
            NSString *fileID = [NSKeyedUnarchiver unarchiveObjectWithData:dataFileID];
            
            if (fileID) {
                
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
            
                if (metadata) {
            
                    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account = %@", metadata.account]];
                
                    if (account) {
                
                        NSString *directoryUser = [CCUtility getDirectoryActiveUser:account.user activeUrl:account.url];
            
                        if (directoryUser)
                            if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileID]])
                                return YES;
                    }
                }
            }
        }
            
        return NO;
    }
    
    if (@selector(pasteFiles:) == action || @selector(pasteFilesEncrypted:) == action) {
        
        BOOL isValid = NO;
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray *items = [pasteboard items];
        
        if ([items count] <= 1) return NO;
        
        for (NSDictionary *dic in items) {
            
            // Value : (NSData) fileID
            
            NSData *dataFileID = [dic objectForKey: k_metadataKeyedUnarchiver];
            NSString *fileID = [NSKeyedUnarchiver unarchiveObjectWithData:dataFileID];

            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
            
            if (metadata) {
            
                tableAccount *account = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account = %@", metadata.account]];

                if (account) {
                
                    NSString *directoryUser = [CCUtility getDirectoryActiveUser:account.user activeUrl:account.url];
            
                    if (directoryUser) {
                        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileID]]) {
                            isValid = YES;
                        } else {
                            isValid = NO;
                            break;
                        }
                    } else {
                        isValid = NO;
                        break;
                    }
                } else {
                    isValid = NO;
                    break;
                }
            } else {
                isValid = NO;
                break;
            }
        }
        
        return isValid;
    }
    
    return NO;
}

/************************************ COPY ************************************/

- (void)copyFile:(id)sender
{
    // Remove all item
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.items = [[NSArray alloc] init];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser,_metadata.fileID]]) {
        
        [self copyFileToPasteboard:_metadata];
        
    } else {
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
        
        [[CCNetworking sharedNetworking] downloadFile:_metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorLoadCopy selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
    }
}

- (void)copyFiles:(id)sender
{
    // Remove all item
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.items = [[NSArray alloc] init];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    for (tableMetadata *metadata in selectedMetadatas) {
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]]) {
            
            [self copyFileToPasteboard:metadata];
            
        } else {

            NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];

            [[CCNetworking sharedNetworking] downloadFile:metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorLoadCopy selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
        }
    }
    
    [self tableViewSelect:NO];
}

- (void)copyFileToPasteboard:(tableMetadata *)metadata
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSMutableArray *items = [[NSMutableArray alloc] initWithArray:pasteboard.items];
    
    // Value : (NSData) fileID
    
    NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:[NSKeyedArchiver archivedDataWithRootObject:metadata.fileID], k_metadataKeyedUnarchiver,nil];
    [items addObject:item];
    
    [pasteboard setItems:items];
}

/************************************ OPEN IN ... ************************************/

- (void)openinFile:(id)sender
{
    [self openIn:_metadata];
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
    float timer = 0;
    
    for (NSDictionary *dic in items) {
        
        // Value : (NSData) fileID
        
        NSData *dataFileID = [dic objectForKey: k_metadataKeyedUnarchiver];
        NSString *fileID = [NSKeyedUnarchiver unarchiveObjectWithData:dataFileID];
        
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
        if (metadata) {
            
            tableAccount *account = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account = %@", metadata.account]];
            
            if (account) {
                
                NSString *directoryUser = [CCUtility getDirectoryActiveUser:account.user activeUrl:account.url];
                
                if (directoryUser) {
                    
                    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileID]]) {
                        
                        [CCUtility copyFileAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, metadata.fileID] toPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileNamePrint]];
                        
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timer * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            [[CCNetworking sharedNetworking] uploadFile:metadata.fileNamePrint serverUrl:_serverUrl cryptated:cryptated onlyPlist:NO session:k_upload_session taskStatus:k_taskStatusResume selector:nil selectorPost:nil errorCode:0 delegate:nil];
                        });
                        
                        timer += 0.1;
                    }
                }
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
                
                // verifichiamo se il passcode è corretto per il seguente file -> UUID
                if ([[CCCrypto sharedManager] verifyPasscode:aPasscode uuid:_metadata.uuid text:_metadata.title]) {
                    
                    // scriviamo il passcode
                    [CCUtility setKeyChainPasscodeForUUID:_metadata.uuid conPasscode:aPasscode];
                    
                    [self readFolder:_serverUrl];
                    
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
                
                NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
                NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileNameData];
                
                if (![[NCManageDatabase sharedInstance] setDirectoryLockWithServerUrl:lockServerUrl lock:NO]) {
                
                    [app messageNotification:@"_error_" description:@"_error_operation_canc_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
                }
                
                [self tableViewReloadData];
            }
        }
            break;
        default:
            break;
    }
}

- (void)comandoLockPassword
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileNameData];

    // se non è abilitato il Lock Passcode esci
    if ([[CCUtility getBlockCode] length] == 0) {
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_warning_", nil) message:NSLocalizedString(@"_only_lock_passcode_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
        return;
    }
    
    // se è richiesta la disattivazione si chiede la password
    
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", app.activeAccount, lockServerUrl]];
    
    if (directory.lock) {
        
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
        
        BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
        touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
        viewController.touchIDManager = touchIDManager;

        viewController.title = NSLocalizedString(@"_passcode_protection_", nil);
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [self presentViewController:navigationController animated:YES completion:nil];
        
        return;
    }
    
    // ---------------- ACTIVATE PASSWORD
    
    if ([[NCManageDatabase sharedInstance] setDirectoryLockWithServerUrl:lockServerUrl lock:YES]) {
        
        NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:_metadata.fileID];
        if ([self indexPathIsValid:indexPath])
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
        
    } else {
        
        [app messageNotification:@"_error_" description:@"_error_operation_canc_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
    }
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Swipe Tablet -> menu =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (!metadata || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata])
        return NO;
    
    if (metadata == nil || metadata.errorPasscode || (metadata.cryptated && [metadata.title length] == 0) || metadata.sessionTaskIdentifier  != k_taskIdentifierDone || metadata.sessionTaskIdentifier != k_taskIdentifierDone)
        return NO;
    else
        return YES;
}

-(void)swipeTableCell:(nonnull MGSwipeTableCell *)cell didChangeSwipeState:(MGSwipeState)state gestureIsActive:(BOOL)gestureIsActive
{
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell tappedButtonAtIndex:(NSInteger)index direction:(MGSwipeDirection)direction fromExpansion:(BOOL)fromExpansion
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
   _metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (direction == MGSwipeDirectionRightToLeft) {
        
        // Delete
        if (index == 0)
            [self swipeDelete:indexPath];
        
        // More
        if (index == 1) {
            
            [cell hideSwipeAnimated:NO];
            [self performSelector:@selector(swipeMore:) withObject:indexPath afterDelay:0.1];
        }
    }
    
    if (direction == MGSwipeDirectionLeftToRight) {
        if (_metadata.favorite)
            [self removeFavorite:_metadata];
        else
            [self addFavorite:_metadata];
    }
    
    return YES;
}

- (void)swipeDelete:(NSIndexPath *)indexPath
{
    // Directory locked ?
    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:[[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID] addFileName:_metadata.fileNameData];
    
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", app.activeAccount, lockServerUrl]];
    
    if (directory.lock && [[CCUtility getBlockCode] length] && app.sessionePasscodeLock == nil) {
        
        [app messageNotification:@"_error_" description:@"_folder_blocked_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:0];
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self performSelector:@selector(deleteFile) withObject:nil];
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    alertController.popoverPresentationController.sourceView = self.view;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)swipeMore:(NSIndexPath *)indexPath
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    
    NSString *titoloCriptaDecripta, *titoloLock, *titleFavorite;
    
    if (_metadata.cryptated) titoloCriptaDecripta = [NSString stringWithFormat:NSLocalizedString(@"_decrypt_", nil)];
    else titoloCriptaDecripta = [NSString stringWithFormat:NSLocalizedString(@"_encrypt_", nil)];
    
    if (_metadata.favorite) {
        
        titleFavorite = [NSString stringWithFormat:NSLocalizedString(@"_remove_favorites_", nil)];
    } else {
        
        titleFavorite = [NSString stringWithFormat:NSLocalizedString(@"_add_favorites_", nil)];
    }
    
    if (_metadata.directory) {
        // calcolo lockServerUrl
        NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileNameData];
        
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", app.activeAccount, lockServerUrl]];
        
        if (directory.lock)
            titoloLock = [NSString stringWithFormat:NSLocalizedString(@"_remove_passcode_", nil)];
        else
            titoloLock = [NSString stringWithFormat:NSLocalizedString(@"_protect_passcode_", nil)];
    }
    
    tableLocalFile *localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", _metadata.fileID]];
    
    // ******************************************* AHKActionSheet *******************************************
    
    AHKActionSheet *actionSheet = [[AHKActionSheet alloc] initWithView:self.view title:nil];
    
    actionSheet.animationDuration = 0.2;
    
    actionSheet.blurRadius = 0.0f;
    actionSheet.blurTintColor = [UIColor colorWithWhite:0.0f alpha:0.50f];
    
    actionSheet.buttonHeight = 50.0;
    actionSheet.cancelButtonHeight = 50.0f;
    actionSheet.separatorHeight = 5.0f;
    
    actionSheet.automaticallyTintButtonImages = @(NO);
    
    actionSheet.encryptedButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[NCBrandColor sharedInstance].cryptocloud };
    actionSheet.buttonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[UIColor blackColor] };
    actionSheet.cancelButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[NCBrandColor sharedInstance].brand };
    actionSheet.disableButtonTextAttributes = @{ NSFontAttributeName:[UIFont systemFontOfSize:16], NSForegroundColorAttributeName:[UIColor blackColor] };
    
    actionSheet.separatorColor =  [NCBrandColor sharedInstance].seperator;
    actionSheet.cancelButtonTitle = NSLocalizedString(@"_cancel_",nil);
    
    // ******************************************* DIRECTORY *******************************************
    
    if (_metadata.directory) {
        
        BOOL lockDirectory = NO;
        NSString *dirServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileNameData];
        
        // Directory bloccata ?
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", app.activeAccount, dirServerUrl]];
        
        if (directory.lock && [[CCUtility getBlockCode] length] && app.sessionePasscodeLock == nil) lockDirectory = YES;
        
        NSString *autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
        NSString *autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:app.activeUrl];
        
        [actionSheet addButtonWithTitle: _metadata.fileNamePrint
                                  image: [CCGraphics changeThemingColorImage:[UIImage imageNamed:_metadata.iconName] color:[NCBrandColor sharedInstance].brand]
                        backgroundColor: [NCBrandColor sharedInstance].tabBar
                                 height: 50.0
                                   type: AHKActionSheetButtonTypeDisabled
                                handler: nil
        ];
        
        if (_metadata.cryptated == NO && !lockDirectory) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_share_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetShare"] color:[NCBrandColor sharedInstance].brand]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        [self openWindowShare:_metadata];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:autoUploadFileName] == YES && [serverUrl isEqualToString:autoUploadDirectory] == YES) && !lockDirectory) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_rename_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetRename"] color:[NCBrandColor sharedInstance].brand]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_rename_",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
                                        
                                        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                                            textField.text = _metadata.fileNamePrint;
                                            //textField.selectedTextRange = [textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument];
                                            //textField.delegate = self;
                                            [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                                        }];
                                        
                                        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                                            NSLog(@"Cancel action");
                                        }];
                                        
                                        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                            
                                            UITextField *fileName = alertController.textFields.firstObject;
                                            
                                            [self performSelectorOnMainThread:@selector(renameFile:) withObject:[NSMutableArray arrayWithObjects:_metadata,fileName.text, nil] waitUntilDone:NO];
                                        }];
                                        
                                        okAction.enabled = NO;
                                        
                                        [alertController addAction:cancelAction];
                                        [alertController addAction:okAction];
                                        
                                        [self presentViewController:alertController animated:YES completion:nil];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:autoUploadFileName] == YES && [serverUrl isEqualToString:autoUploadDirectory] == YES) && !lockDirectory) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_move_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetMove"] color:[NCBrandColor sharedInstance].brand]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        [self moveOpenWindow:[[NSArray alloc] initWithObjects:indexPath, nil]];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:autoUploadFileName] == YES && [serverUrl isEqualToString:autoUploadDirectory] == YES) && _metadata.cryptated == NO) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_folder_automatic_upload_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folderphotocamera"] color:[NCBrandColor sharedInstance].brand]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        // Settings new folder Automatatic upload
                                        NSString *oldAutoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:app.activeUrl];
                                        
                                        [[NCManageDatabase sharedInstance] setAccountAutoUploadFileName:_metadata.fileName];
                                        [[NCManageDatabase sharedInstance] setAccountAutoUploadDirectory:serverUrl activeUrl:app.activeUrl];
                                        
                                        [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:oldAutoUploadDirectory directoryID:nil];
                                        
                                        if (app.activeAccount.length > 0 && app.activePhotos)
                                            [app.activePhotos reloadDatasourceForced];
                                        
                                        [self readFolder:serverUrl];
                                        
                                        NSLog(@"[LOG] Update Folder Photo");
                                        NSString *autoUploadPath = [[NCManageDatabase sharedInstance] getAccountAutoUploadPath:app.activeUrl];
                                        if ([autoUploadPath length] > 0)
                                            [[CCSynchronize sharedSynchronize] synchronizedFolder:autoUploadPath selector:selectorReadFolder];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:autoUploadFileName] == YES && [serverUrl isEqualToString:autoUploadDirectory] == YES)) {
            
            [actionSheet addButtonWithTitle:titoloLock
                                      image:[UIImage imageNamed:@"actionSheetLock"]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeEncrypted
                                    handler:^(AHKActionSheet *as) {
                                        
                                        [self performSelector:@selector(comandoLockPassword) withObject:nil];
                                    }];
        }
        
        if (!([_metadata.fileName isEqualToString:autoUploadFileName] == YES && [serverUrl isEqualToString:autoUploadDirectory] == YES) && !lockDirectory && app.isCryptoCloudMode) {
            
            [actionSheet addButtonWithTitle:titoloCriptaDecripta
                                      image:[UIImage imageNamed:@"actionSheetCrypto"]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeEncrypted
                                    handler:^(AHKActionSheet *as) {
                                        
                                        [self performSelector:@selector(encyptedDecryptedFolder) withObject:nil];
                                    }];
        }
        
        [actionSheet show];
    }
    
    // ******************************************* FILE *******************************************
    
    if ([_metadata.type isEqualToString: k_metadataType_file] && !_metadata.directory) {
        
        UIImage *iconHeader;
        
        // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, _metadata.fileID]])
            iconHeader = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, _metadata.fileID]];
        else
            iconHeader = [UIImage imageNamed:_metadata.iconName];
        
        [actionSheet addButtonWithTitle: _metadata.fileNamePrint
                                  image: iconHeader
                        backgroundColor: [NCBrandColor sharedInstance].tabBar
                                 height: 50.0
                                   type: AHKActionSheetButtonTypeDisabled
                                handler: nil
        ];
        
        if (_metadata.cryptated == NO) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_share_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetShare"] color:[NCBrandColor sharedInstance].brand]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        [self openWindowShare:_metadata];
                                    }];
        }
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_open_in_", nil)
                                  image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetOpenIn"] color:[NCBrandColor sharedInstance].brand]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    [self performSelector:@selector(openIn:) withObject:_metadata];
                                }];
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_rename_", nil)
                                  image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetRename"] color:[NCBrandColor sharedInstance].brand]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_rename_",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
                                    
                                    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                                        //textField.placeholder = _metadata.fileNamePrint;
                                        textField.text = _metadata.fileNamePrint;
                                        [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                                    }];
                                    
                                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                                        NSLog(@"Cancel action");
                                    }];
                                    
                                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                        
                                        UITextField *fileName = alertController.textFields.firstObject;
                                        
                                        [self performSelectorOnMainThread:@selector(renameFile:) withObject:[NSMutableArray arrayWithObjects:_metadata,fileName.text, nil] waitUntilDone:NO];
                                    }];
                                    
                                    okAction.enabled = NO;
                                    
                                    [alertController addAction:cancelAction];
                                    [alertController addAction:okAction];
                                    
                                    [self presentViewController:alertController animated:YES completion:nil];
                                }];
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_move_", nil)
                                  image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetMove"] color:[NCBrandColor sharedInstance].brand]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    [self moveOpenWindow:[[NSArray alloc] initWithObjects:indexPath, nil]];
                                }];
        
        if (localFile || [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, _metadata.fileID]]) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_remove_local_file_", nil)
                                      image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetRemoveLocal"] color:[NCBrandColor sharedInstance].brand]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        [self performSelector:@selector(removeLocalFile:) withObject:_metadata];
                                    }];
        }
        
        if (app.isCryptoCloudMode) {
            
            [actionSheet addButtonWithTitle:titoloCriptaDecripta
                                      image:[UIImage imageNamed:@"actionSheetCrypto"]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeEncrypted
                                    handler:^(AHKActionSheet *as) {
                                        
                                        [self performSelector:@selector(cmdEncryptedDecryptedFile) withObject:nil];
                                    }];
        }
        
#ifdef DEBUG
        
        /*
        [actionSheet addButtonWithTitle:@"Hide file"
                                  image:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"admin"] color:[NCBrandColor sharedInstance].brand]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                    
                                    [[NCManageDatabase sharedInstance] setMetadataStatusWithFileID:_metadata.fileID status:k_metadataStatusHide];
                                    
                                    [self reloadDatasource];
                                }];
        */ 
        
#endif

        [actionSheet show];
    }
    
    // ******************************************* TEMPLATE *******************************************
    
    if ([_metadata.type isEqualToString: k_metadataType_template]) {
        
        [actionSheet addButtonWithTitle: _metadata.fileNamePrint
                                  image: [UIImage imageNamed:_metadata.iconName]
                        backgroundColor: [NCBrandColor sharedInstance].tabBar
                                 height: 50.0
                                   type: AHKActionSheetButtonTypeDisabled
                                handler: nil
         ];
        
        if ([_metadata.model isEqualToString:@"note"]) {
            
            [actionSheet addButtonWithTitle:NSLocalizedString(@"_rename_", nil)
                                      image:[UIImage imageNamed:@"actionSheetRename"]
                            backgroundColor:[UIColor whiteColor]
                                     height: 50.0
                                       type:AHKActionSheetButtonTypeDefault
                                    handler:^(AHKActionSheet *as) {
                                        
                                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_rename_",nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
                                        
                                        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                                            textField.placeholder = _metadata.fileNamePrint;
                                            [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                                        }];
                                        
                                        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                                            NSLog(@"Cancel action");
                                        }];
                                        
                                        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                            
                                            UITextField *fileName = alertController.textFields.firstObject;
                                            
                                            [self performSelectorOnMainThread:@selector(renameNote:) withObject:[NSMutableArray arrayWithObjects:_metadata,fileName.text, nil] waitUntilDone:NO];
                                        }];
                                        
                                        okAction.enabled = NO;
                                        
                                        [alertController addAction:cancelAction];
                                        [alertController addAction:okAction];
                                        
                                        [self presentViewController:alertController animated:YES completion:nil];
                                    }];
        }
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"_move_", nil)
                                  image:[UIImage imageNamed:@"actionSheetMove"]
                        backgroundColor:[UIColor whiteColor]
                                 height: 50.0
                                   type:AHKActionSheetButtonTypeDefault
                                handler:^(AHKActionSheet *as) {
                                                                        
                                    [self moveOpenWindow:[[NSArray alloc] initWithObjects:indexPath, nil]];
                                }];
        
        [actionSheet show];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)clearDateReadDataSource:(NSNotification *)notification
{
    _dateReadDataSource = Nil;
    [self reloadDatasource];
}

- (void)reloadDatasource
{
    [self reloadDatasource:_serverUrl];
}

- (void)reloadDatasource:(NSString *)serverUrl
{
    // test
    if (app.activeAccount.length == 0 || serverUrl.length == 0)
        return;
    
    // Search Mode
    if(_isSearchMode) {
        
        _sectionDataSource = [CCSectionMetadata creataDataSourseSectionMetadata:_searchResultMetadatas listProgressMetadata:nil groupByField:_directoryGroupBy replaceDateToExifDate:NO activeAccount:app.activeAccount];

        [self tableViewReloadData];
        
        if ([_sectionDataSource.allRecordsDataSource count] == 0 && [_searchFileName length] >= k_minCharsSearch) {
            
            _noFilesSearchTitle = NSLocalizedString(@"_search_no_record_found_", nil);
            _noFilesSearchDescription = @"";
        }
        
        if ([_sectionDataSource.allRecordsDataSource count] == 0 && [_searchFileName length] < k_minCharsSearch) {
            
            _noFilesSearchTitle = @"";
            _noFilesSearchDescription = NSLocalizedString(@"_search_instruction_", nil);
        }
    
        [self.tableView reloadEmptyDataSet];
        
        return;
    }
    
    // Reload -> Self se non siamo nella dir appropriata cercala e se è in memoria reindirizza il reload
    if ([serverUrl isEqualToString:_serverUrl] == NO || _serverUrl == nil) {
        
        CCMain *main = [app.listMainVC objectForKey:serverUrl];
        if (main) {
            [main reloadDatasource];
        } else {
            [self tableViewReloadData];
            [app.activeTransfers reloadDatasource];
        }
        
        return;
    }
    
    [app.activeTransfers reloadDatasource];
    
    // Settaggio variabili per le ottimizzazioni
    _directoryGroupBy = [CCUtility getGroupBySettings];
    _directoryOrder = [CCUtility getOrderSettings];
    
    // Controllo data lettura Data Source
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", app.activeAccount, serverUrl]];
    
    NSDate *dateDateRecordDirectory = directory.dateReadDirectory;
    
    if ([dateDateRecordDirectory compare:_dateReadDataSource] == NSOrderedDescending || dateDateRecordDirectory == nil || _dateReadDataSource == nil) {
        
        NSLog(@"[LOG] Rebuild Data Source File : %@", _serverUrl);

        _dateReadDataSource = [NSDate date];
    
        // Data Source
        
        NSString *sorted = _directoryOrder;
        if ([sorted isEqualToString:@"fileName"])
            sorted = @"fileNamePrint";
    
        NSArray *recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND status = %i", app.activeAccount, [[NCManageDatabase sharedInstance] getDirectoryID:serverUrl], k_metadataStatusNormal] sorted:sorted ascending:[CCUtility getAscendingSettings]];
        
        _sectionDataSource = [CCSectionDataSourceMetadata new];
        _sectionDataSource = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:nil groupByField:_directoryGroupBy replaceDateToExifDate:NO activeAccount:app.activeAccount];
        
    } else {
        
         NSLog(@"[LOG] [OPTIMIZATION] Rebuild Data Source File : %@ - %@", _serverUrl, _dateReadDataSource);
    }
    
    [self tableViewReloadData];
}

- (NSArray *)getMetadatasFromSelectedRows:(NSArray *)selectedRows
{
    NSMutableArray *metadatas = [[NSMutableArray alloc] init];
    
    if (selectedRows.count > 0) {
    
        for (NSIndexPath *selectionIndex in selectedRows) {
            
            NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:selectionIndex.section]] objectAtIndex:selectionIndex.row];
            tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];

            [metadatas addObject:metadata];
        }
    }
    
    return metadatas;
}

- (tableMetadata *)getMetadataFromSectionDataSource:(NSIndexPath *)indexPath
{
    NSInteger section = indexPath.section + 1;
    NSInteger row = indexPath.row + 1;
    
    NSInteger totSections = [_sectionDataSource.sections count] ;
    
    if ((totSections < section) || (section > totSections)) {
      
        NSLog(@"[LOG] %@", [NSString stringWithFormat:@"DEBUG [0] : error section, totSections = %lu - section = %lu", (long)totSections, (long)section]);
        return nil;
    }
    
    id valueSection = [_sectionDataSource.sections objectAtIndex:indexPath.section];
    
    NSArray *fileIDs = [_sectionDataSource.sectionArrayRow objectForKey:valueSection];
    
    if (fileIDs) {
        
        NSInteger totRows =[fileIDs count] ;
        
        if ((totRows < row) || (row > totRows)) {
            
            NSLog(@"[LOG] %@", [NSString stringWithFormat:@"DEBUG [1] : error row, totRows = %lu - row = %lu", (long)totRows, (long)row]);
            return nil;
        }

    } else {
        
        NSLog(@"[LOG] DEBUG [2] : fileIDs is NIL");
        return nil;
    }
        
    NSString *fileID = [fileIDs objectAtIndex:indexPath.row];
    tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
    
    return metadata;
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
    if (edit)
        [self.tableView setEditing:NO animated:NO];
    
    [self.tableView setAllowsMultipleSelectionDuringEditing:edit];
    [self.tableView setEditing:edit animated:YES];
    _isSelectedMode = edit;
    
    if (edit)
        [self setUINavigationBarSelected];
    else
        [self setUINavigationBarDefault];
    
    [_selectedFileIDsMetadatas removeAllObjects];
    
    [self setTitle];
}

- (void)tableViewReloadData
{
    // store selected cells before relod
    NSArray *indexPaths = [self.tableView indexPathsForSelectedRows];
    
    //store swipeOffset before relod
    [_statusSwipeCell removeAllObjects];
    for (MGSwipeTableCell *cell in self.tableView.visibleCells) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        [_statusSwipeCell setObject:[NSNumber numberWithDouble:cell.swipeOffset] forKey:indexPath];
    }
    
    // reload table view
    [self.tableView reloadData];
    
    // selected cells stored
    for (NSIndexPath *path in indexPaths)
        [self.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    
    [self setTableViewFooter];
    
    if (self.tableView.editing)
        [self setTitle];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{    
    if (tableView.editing == 1) {
        
        tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
        
        if (!metadata || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata])
            return NO;
        
        if (metadata == nil || metadata.errorPasscode || (metadata.cryptated && [metadata.title length] == 0) || metadata.sessionTaskIdentifier  != k_taskIdentifierDone || metadata.sessionTaskIdentifier != k_taskIdentifierDone)
            return NO;
        else
            return YES;
        
    } else {
        
        [_selectedFileIDsMetadatas removeAllObjects];
    }
    
    return YES;
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
    
    if ([_directoryGroupBy isEqualToString:@"none"] && [sections count] <= 1) return 0.0f;
    
    return 20.f;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    float shift;
    UIVisualEffectView *visualEffectView;
    
    NSString *titleSection;
    
    if (![self indexPathIsValid:[NSIndexPath indexPathForRow:0 inSection:section]])
        return nil;
    
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]])
        titleSection = [_sectionDataSource.sections objectAtIndex:section];
    
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSDate class]])
        titleSection = [CCUtility getTitleSectionDate:[_sectionDataSource.sections objectAtIndex:section]];
    
    if ([titleSection isEqualToString:@"_none_"]) titleSection = @"";
    else if ([titleSection rangeOfString:@"download"].location != NSNotFound) titleSection = NSLocalizedString(@"_title_section_download_",nil);
    else if ([titleSection rangeOfString:@"upload"].location != NSNotFound) titleSection = NSLocalizedString(@"_title_section_upload_",nil);
    else titleSection = NSLocalizedString(titleSection,nil);
    
    // Format title
    NSString *currentDevice = [CCUtility currentDevice];
    if ([currentDevice rangeOfString:@"iPad3"].location != NSNotFound) {
        
        visualEffectView = [[UIVisualEffectView alloc] init];
        visualEffectView.backgroundColor = [[NCBrandColor sharedInstance].brand colorWithAlphaComponent:0.3];
        
    } else {
        
        UIVisualEffect *blurEffect;
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        visualEffectView.backgroundColor = [[NCBrandColor sharedInstance].brand colorWithAlphaComponent:0.2];
    }
    
    if ([_directoryGroupBy isEqualToString:@"alphabetic"]) {
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            shift = - 35;
        else
            shift =  - 20;
        
    } else shift = - 10;
    
    // Title
    UILabel *titleLabel = [[UILabel alloc]initWithFrame:CGRectMake(10, -12, 0, 44)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont systemFontOfSize:12];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.text = titleSection;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    [visualEffectView addSubview:titleLabel];
    
    // Elements
    UILabel *elementLabel= [[UILabel alloc]initWithFrame:CGRectMake(shift, -12, 0, 44)];
    elementLabel.backgroundColor = [UIColor clearColor];
    elementLabel.textColor = [UIColor blackColor];;
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
    
    tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    if (!metadata || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata]) {
        return [tableView dequeueReusableCellWithIdentifier:@"CellMainTransfer"];
    }
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    
    if ([metadata.session isEqualToString:@""] || metadata.session == nil) typeCell = @"CellMain";
    else typeCell = @"CellMainTransfer";
    
    CCCellMainTransfer *cell = (CCCellMainTransfer *)[tableView dequeueReusableCellWithIdentifier:typeCell forIndexPath:indexPath];
    
    // variable base
    cell.delegate = self;
    cell.indexPath = indexPath;
    
    // separator
    cell.separatorInset = UIEdgeInsetsMake(0.f, 60.f, 0.f, 0.f);
    
    // change color selection
    UIView *selectionColor = [[UIView alloc] init];
    selectionColor.backgroundColor = [[NCBrandColor sharedInstance] getColorSelectBackgrond];
    cell.selectedBackgroundView = selectionColor;
    
    if ([typeCell isEqualToString:@"CellMain"]) cell.backgroundColor = [UIColor whiteColor];
    if ([typeCell isEqualToString:@"CellMainTransfer"]) cell.backgroundColor = [NCBrandColor sharedInstance].transferBackground;
    
    // ----------------------------------------------------------------------------------------------------------
    // DEFAULT
    // ----------------------------------------------------------------------------------------------------------
    
    cell.file.image = nil;
    cell.status.image = nil;
    cell.favorite.image = nil;
    cell.shared.image = nil;
    cell.local.image = nil;
    
    cell.labelTitle.enabled = YES;
    cell.labelTitle.text = @"";
    cell.labelInfoFile.enabled = YES;
    cell.labelInfoFile.text = @"";
    
    cell.progressView.progress = 0.0;
    cell.progressView.hidden = YES;
    
    cell.cancelTaskButton.hidden = YES;
    cell.reloadTaskButton.hidden = YES;
    cell.stopTaskButton.hidden = YES;
    
    // Encrypted color
    if (metadata.cryptated) {
        cell.labelTitle.textColor = [NCBrandColor sharedInstance].cryptocloud;
    } else {
        cell.labelTitle.textColor = [UIColor blackColor];
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
        // Favorite Folder
        // ----------------------------------------------------------------------------------------------------------
        
        if (metadata.favorite) {
            
            cell.favorite.image = [UIImage imageNamed:@"favorite"];
        }
        
    } else {
    
        // File                
        dataFile = [CCUtility dateDiff:metadata.date];
        lunghezzaFile = [CCUtility transformedSize:metadata.size];
        
        // Plist ancora da scaricare
        if (metadata.cryptated && [metadata.title length] == 0) {
            
            dataFile = @" ";
            lunghezzaFile = @" ";
        }
        
        tableLocalFile *localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", metadata.fileID]];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        
        if ([metadata.type isEqualToString: k_metadataType_template] && [dataFile isEqualToString:@" "] == NO && [lunghezzaFile isEqualToString:@" "] == NO)
            cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", dataFile];
        
        if ([metadata.type isEqualToString: k_metadataType_file] && [dataFile isEqualToString:@" "] == NO && [lunghezzaFile isEqualToString:@" "] == NO) {
            if (localFile && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]])
                cell.local.image = [UIImage imageNamed:@"local"];
            else
                cell.local.image = nil;
            
            //cell.labelInfoFile.text = [NSString stringWithFormat:@"%@ • %@", dataFile, lunghezzaFile];
            //cell.labelInfoFile.text = [NSString stringWithFormat:@"%@ ◦ %@", dataFile, lunghezzaFile];
            cell.labelInfoFile.text = [NSString stringWithFormat:@"%@ %@", dataFile, lunghezzaFile];
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
        
        cell.file.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        
    } else {
        
        if (metadata.directory)
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:metadata.iconName] color:[NCBrandColor sharedInstance].brand];
        else
            cell.file.image = [UIImage imageNamed:metadata.iconName];
        
        if (metadata.thumbnailExists)
            [[CCActions sharedInstance] downloadTumbnail:metadata delegate:self];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // Image Status cyptated & Lock Passcode
    // ----------------------------------------------------------------------------------------------------------
    
    // File Cyptated
    if (metadata.cryptated && metadata.directory == NO && [metadata.type isEqualToString: k_metadataType_template] == NO) {
     
        cell.status.image = [UIImage imageNamed:@"lock"];
    }
    
    // Directory con passcode lock attivato
    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileNameData];
    
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", app.activeAccount, lockServerUrl]];
    
    if (metadata.directory && (directory.lock && [[CCUtility getBlockCode] length]))
        cell.status.image = [UIImage imageNamed:@"passcode"];
    
    // ----------------------------------------------------------------------------------------------------------
    // Favorite
    // ----------------------------------------------------------------------------------------------------------
    
    if (metadata.favorite) {
        
        cell.favorite.image = [UIImage imageNamed:@"favorite"];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // Share
    // ----------------------------------------------------------------------------------------------------------

    NSString *shareLink = [app.sharesLink objectForKey:[serverUrl stringByAppendingString:metadata.fileName]];
    NSString *shareUserAndGroup = [app.sharesUserAndGroup objectForKey:[serverUrl stringByAppendingString:metadata.fileName]];
    BOOL isShare = ([metadata.permissions length] > 0) && ([metadata.permissions rangeOfString:k_permission_shared].location != NSNotFound) && ([_fatherPermission rangeOfString:k_permission_shared].location == NSNotFound);
    BOOL isMounted = ([metadata.permissions length] > 0) && ([metadata.permissions rangeOfString:k_permission_mounted].location != NSNotFound) && ([_fatherPermission rangeOfString:k_permission_mounted].location == NSNotFound);
    
    // Aggiungiamo il Tap per le shared
    if (isShare || [shareLink length] > 0 || [shareUserAndGroup length] > 0 || isMounted) {
    
        if (isShare) {
       
            if (metadata.directory) {
                
                cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder_shared_with_me"] color:[NCBrandColor sharedInstance].brand];
                cell.shared.userInteractionEnabled = NO;
                
            } else {
            
                cell.shared.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetShare"] color:[NCBrandColor sharedInstance].brand];
            
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionConnectionMounted:)];
                [tap setNumberOfTapsRequired:1];
                cell.shared.userInteractionEnabled = YES;
                [cell.shared addGestureRecognizer:tap];
            }
        }
        
        if (isMounted) {
            
            if (metadata.directory) {
                
                cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder_external"] color:[NCBrandColor sharedInstance].brand];
                cell.shared.userInteractionEnabled = NO;
                
            } else {
                
                cell.shared.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"shareMounted"] color:[NCBrandColor sharedInstance].brand];
                
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionConnectionMounted:)];
                [tap setNumberOfTapsRequired:1];
                cell.shared.userInteractionEnabled = YES;
                [cell.shared addGestureRecognizer:tap];
            }
        }
        
        if ([shareLink length] > 0 || [shareUserAndGroup length] > 0) {
        
            if (metadata.directory) {
                
                if ([shareLink length] > 0)
                    cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder_public"] color:[NCBrandColor sharedInstance].brand];
                if ([shareUserAndGroup length] > 0)
                    cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder_shared_with_me"] color:[NCBrandColor sharedInstance].brand];
                
                cell.shared.userInteractionEnabled = NO;
                
            } else {
                
                if ([shareLink length] > 0)
                    cell.shared.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"shareLink"] color:[NCBrandColor sharedInstance].brand];
                if ([shareUserAndGroup length] > 0)
                    cell.shared.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"actionSheetShare"] color:[NCBrandColor sharedInstance].brand];
                
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionShared:)];
                [tap setNumberOfTapsRequired:1];
                cell.shared.userInteractionEnabled = YES;
                [cell.shared addGestureRecognizer:tap];
            }
        }
        
    } else {
        
        cell.shared.userInteractionEnabled = NO;
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // downloadFile
    // ----------------------------------------------------------------------------------------------------------
    
    if ([metadata.session length] > 0 && [metadata.session containsString:@"download"]) {
        
        if (metadata.cryptated) cell.status.image = [UIImage imageNamed:@"statusdownloadcrypto"];
        else cell.status.image = [UIImage imageNamed:@"statusdownload"];

        // sessionTaskIdentifier : RELOAD + STOP
        if (metadata.sessionTaskIdentifier != k_taskIdentifierDone) {
            
            if (metadata.cryptated)[cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:@"stoptaskcrypto"] forState:UIControlStateNormal];
            else [cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:@"stoptask"] forState:UIControlStateNormal];
            
            cell.cancelTaskButton.hidden = NO;

            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtaskcrypto"] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtask"] forState:UIControlStateNormal];
            
            cell.reloadTaskButton.hidden = NO;
            
        }
        
        // sessionTaskIdentifierPlist : RELOAD
        if (metadata.sessionTaskIdentifierPlist != k_taskIdentifierDone) {
            
            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtaskcrypto"] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtask"] forState:UIControlStateNormal];
            
            cell.reloadTaskButton.hidden = NO;
        }

        cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", lunghezzaFile];
        
        float progress = [[app.listProgressMetadata objectForKey:metadata.fileID] floatValue];
        if (progress > 0) {
            
            if (metadata.cryptated) cell.progressView.progressTintColor = [NCBrandColor sharedInstance].cryptocloud;
            else cell.progressView.progressTintColor = [UIColor blackColor];
            
            cell.progressView.progress = progress;
            cell.progressView.hidden = NO;
        }

        // ----------------------------------------------------------------------------------------------------------
        // downloadFile Error
        // ----------------------------------------------------------------------------------------------------------
        
        if (metadata.sessionTaskIdentifier == k_taskIdentifierError || metadata.sessionTaskIdentifierPlist == k_taskIdentifierError) {
            
            cell.status.image = [UIImage imageNamed:@"statuserror"];
            
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
        
        if (metadata.cryptated) cell.status.image = [UIImage imageNamed:@"statusuploadcrypto"];
        else cell.status.image = [UIImage imageNamed:@"statusupload"];
        
        if (metadata.cryptated)[cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:@"removetaskcrypto"] forState:UIControlStateNormal];
        else [cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:@"removetask"] forState:UIControlStateNormal];
        cell.cancelTaskButton.hidden = NO;
        
        if (metadata.sessionTaskIdentifier == k_taskIdentifierStop) {
            
            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtaskcrypto"] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtask"] forState:UIControlStateNormal];
            
            if (metadata.cryptated) cell.status.image = [UIImage imageNamed:@"statusstopcrypto"];
            else cell.status.image = [UIImage imageNamed:@"statusstop"];
            
            cell.reloadTaskButton.hidden = NO;
            cell.stopTaskButton.hidden = YES;
            
        } else {
            
            if (metadata.cryptated)[cell.stopTaskButton setBackgroundImage:[UIImage imageNamed:@"stoptaskcrypto"] forState:UIControlStateNormal];
            else [cell.stopTaskButton setBackgroundImage:[UIImage imageNamed:@"stoptask"] forState:UIControlStateNormal];
            
            cell.stopTaskButton.hidden = NO;
            cell.reloadTaskButton.hidden = YES;
        }
        
        // se non c'è una preview in bianconero metti l'immagine di default
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]] == NO)
            cell.file.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"uploaddisable"] color:[NCBrandColor sharedInstance].brand];
        
        cell.labelTitle.enabled = NO;
        cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", lunghezzaFile];
        
        float progress = [[app.listProgressMetadata objectForKey:metadata.fileID] floatValue];
        if (progress > 0) {
            
            if (metadata.cryptated) cell.progressView.progressTintColor = [NCBrandColor sharedInstance].cryptocloud;
            else cell.progressView.progressTintColor = [UIColor blackColor];
            
            cell.progressView.progress = progress;
            cell.progressView.hidden = NO;
        }
        
        // ----------------------------------------------------------------------------------------------------------
        // uploadFileError
        // ----------------------------------------------------------------------------------------------------------
    
        if (metadata.sessionTaskIdentifier == k_taskIdentifierError || metadata.sessionTaskIdentifierPlist == k_taskIdentifierError) {
        
            cell.labelTitle.enabled = NO;
            cell.status.image = [UIImage imageNamed:@"statuserror"];
        
            if ([metadata.sessionError length] == 0)
                cell.labelInfoFile.text = [NSString stringWithFormat:@"%@, %@", NSLocalizedString(@"_error_",nil), NSLocalizedString(@"_file_not_uploaded_",nil)];
            else
                cell.labelInfoFile.text = [CCError manageErrorKCF:[metadata.sessionError integerValue] withNumberError:NO];
        }
    }

    [cell.reloadTaskButton addTarget:self action:@selector(reloadTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    [cell.cancelTaskButton addTarget:self action:@selector(cancelTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    [cell.stopTaskButton addTarget:self action:@selector(stopTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];

    // ======== MGSwipe ========

    //Left only plain
    if (metadata.cryptated == NO) {
        
        if (metadata.favorite)
            cell.leftButtons = @[[MGSwipeButton buttonWithTitle:[NSString stringWithFormat:@" %@ ", NSLocalizedString(@"_unfavorite_", nil)] icon:[UIImage imageNamed:@"swipeUnfavorite"] backgroundColor:[UIColor colorWithRed:242.0/255.0 green:220.0/255.0 blue:132.0/255.0 alpha:1.000]]];
        else
            cell.leftButtons = @[[MGSwipeButton buttonWithTitle:[NSString stringWithFormat:@" %@ ", NSLocalizedString(@"_favorite_", nil)] icon:[UIImage imageNamed:@"swipeFavorite"] backgroundColor:[UIColor colorWithRed:242.0/255.0 green:220.0/255.0 blue:132.0/255.0 alpha:1.000]]];
        
        cell.leftExpansion.buttonIndex = 0;
        cell.leftExpansion.fillOnTrigger = NO;
    
        //centerIconOverText
        MGSwipeButton *favoriteButton = (MGSwipeButton *)[cell.leftButtons objectAtIndex:0];
        [favoriteButton centerIconOverText];
        
    } else {
        
        cell.leftButtons = [NSArray new];
    }
    
    //Right
    cell.rightButtons = @[[MGSwipeButton buttonWithTitle:[NSString stringWithFormat:@" %@ ", NSLocalizedString(@"_delete_", nil)] icon:[UIImage imageNamed:@"swipeDelete"] backgroundColor:[UIColor redColor]], [MGSwipeButton buttonWithTitle:[NSString stringWithFormat:@" %@ ", NSLocalizedString(@"_more_", nil)] icon:[UIImage imageNamed:@"swipeMore"] backgroundColor:[UIColor lightGrayColor]]];
    cell.rightSwipeSettings.transition = MGSwipeTransitionBorder;
    
    //centerIconOverText
    MGSwipeButton *deleteButton = (MGSwipeButton *)[cell.rightButtons objectAtIndex:0];
    MGSwipeButton *moreButton = (MGSwipeButton *)[cell.rightButtons objectAtIndex:1];
    [deleteButton centerIconOverText];
    [moreButton centerIconOverText];

    //restore swipeOffset after relod
    CGFloat swipeOffset = [[_statusSwipeCell objectForKey:indexPath] doubleValue];
    if (swipeOffset < 0) {
        [cell showSwipe:MGSwipeDirectionRightToLeft animated:NO];
        [_statusSwipeCell removeObjectForKey:indexPath];
    } else if (swipeOffset > 0) {
        [cell showSwipe:MGSwipeDirectionLeftToRight animated:NO];
        [_statusSwipeCell removeObjectForKey:indexPath];
    }
    
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
    
    // settiamo il record file.
    _metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    // se non può essere selezionata deseleziona
    if ([cell isEditing] == NO)
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // se siamo in modalità editing impostiamo il titolo dei selezioati e usciamo subito
    if (self.tableView.editing) {
        
        [_selectedFileIDsMetadatas setObject:_metadata forKey:_metadata.fileID];
        [self setTitle];
        return;
    }
    
    // test crash
    NSArray *metadatas = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]];
    if (indexPath.row >= [metadatas count]) return;
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
    
    // se è in corso una sessione
    if ([_metadata.session length] > 0) return;
    
    if (_metadata.errorPasscode) {
            
        // se UUID è nil lo sta ancora caricando quindi esci
        if (!_metadata.uuid) return;
        
        // esiste un hint ??
        NSString *hint = [[CCCrypto sharedManager] getHintFromFile:_metadata.fileName isLocal:NO directoryUser:app.directoryUser];
        
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
        
        viewController.title = [NCBrandOptions sharedInstance].brand;
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;

        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
            
        [self presentViewController:navigationController animated:YES completion:nil];
    }
    
    // modello o plist con il title a 0 allora è andato storto qualcosa ... ricaricalo
    if (_metadata.cryptated && [_metadata.title length] == 0) {
    
        NSString* selector;
        
        if ([_metadata.type isEqualToString: k_metadataType_template]) selector = selectorLoadModelView;
        else selector = selectorLoadPlist;
        
        [[CCNetworking sharedNetworking] downloadFile:_metadata.fileID serverUrl:serverUrl downloadData:NO downloadPlist:YES selector:selector selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
        
        return;
    }
        
    // se il plist è caricato ed è un modello aprilo
    if ([_metadata.type isEqualToString:k_metadataType_template]) [self openModel:_metadata.model isNew:false];
    
    // file
    if (_metadata.directory == NO && _metadata.errorPasscode == NO && [_metadata.type isEqualToString: k_metadataType_file]) {
        
        // se il file esiste andiamo direttamente al delegato altrimenti carichiamolo
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, _metadata.fileID]]) {
                            
            [self downloadFileSuccess:_metadata.fileID serverUrl:serverUrl selector:selectorLoadFileView selectorPost:nil];
            
        } else {
                
            [[CCNetworking sharedNetworking] downloadFile:_metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorLoadFileView selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self];
            
            NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:_metadata.fileID];
            if (indexPath) [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    if (_metadata.directory) [self performSegueDirectoryWithControlPasscode:true];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    tableMetadata *metadata = [self getMetadataFromSectionDataSource:indexPath];
    
    [_selectedFileIDsMetadatas removeObjectForKey:metadata.fileID];
    
    [self setTitle];
}

- (BOOL)indexPathIsValid:(NSIndexPath *)indexPath
{
    if (!indexPath)
        return NO;
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    NSInteger lastSectionIndex = [self numberOfSectionsInTableView:self.tableView] - 1;
    
    //Make sure the specified section exists
    if (section > lastSectionIndex)
        return NO;
    
    NSInteger rowCount = [self.tableView numberOfRowsInSection:indexPath.section] - 1;
    
    return row <= rowCount;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)shouldPerformSegue
{
    // if background return
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) return NO;
    
    if (self.view.window == NO)
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
    NSMutableArray *allRecordsDataSourceImagesVideos = [NSMutableArray new];
    tableMetadata *metadata;
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        
        UINavigationController *nav = viewController;
        _detailViewController = (CCDetail *)nav.topViewController;
        
    } else {
        
        _detailViewController = segue.destinationViewController;
    }
    
    if ([sender isKindOfClass:[tableMetadata class]]) {
    
        metadata = sender;
        [allRecordsDataSourceImagesVideos addObject:sender];
        
    } else {
        
        metadata = _metadata;
        
        for (NSString *fileID in _sectionDataSource.allEtag) {
            tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image] || [metadata.typeFile isEqualToString: k_metadataTypeFile_video])
                [allRecordsDataSourceImagesVideos addObject:metadata];
        }
    }
    
    _detailViewController.metadataDetail = metadata;
    _detailViewController.dataSourceImagesVideos = allRecordsDataSourceImagesVideos;
    _detailViewController.dateFilterQuery = nil;
    
    [_detailViewController setTitle:metadata.fileNamePrint];
}

// can i go to next viewcontroller
- (void)performSegueDirectoryWithControlPasscode:(BOOL)controlPasscode
{
    NSString *nomeDir;

    if(self.tableView.editing == NO && _metadata.errorPasscode == NO){
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
        NSString *lockServerUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:_metadata.fileNameData];
        
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", app.activeAccount, lockServerUrl]];
        
        // SE siamo in presenza di una directory bloccata E è attivo il block E la sessione password Lock è senza data ALLORA chiediamo la password per procedere
        if (directory.lock && [[CCUtility getBlockCode] length] && app.sessionePasscodeLock == nil && controlPasscode) {
            
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

            BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
            touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
            viewController.touchIDManager = touchIDManager;
            
            viewController.title = NSLocalizedString(@"_folder_blocked_", nil); 
            viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
            viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;
            
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            [self presentViewController:navController animated:YES completion:nil];
            
            return;
        }
        
        if (_metadata.cryptated) nomeDir = [_metadata.fileName substringToIndex:[_metadata.fileName length]-6];
        else nomeDir = _metadata.fileName;
        
        NSString *serverUrlPush = [CCUtility stringAppendServerUrl:serverUrl addFileName:nomeDir];
        
        CCMain *viewController = [app.listMainVC objectForKey:serverUrlPush];
        
        if (viewController.isViewLoaded == false || viewController == nil) {
            
            viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMainVC"];
            
            viewController.isFolderEncrypted = _metadata.cryptated;
            viewController.serverUrl = serverUrlPush;
            viewController.titleMain = _metadata.fileNamePrint;
            viewController.textBackButton = _titleMain;
            
            // save self
            [app.listMainVC setObject:viewController forKey:serverUrlPush];
        }
        
        // OFF SearchBar
        [viewController cancelSearchBar];
        
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

@end

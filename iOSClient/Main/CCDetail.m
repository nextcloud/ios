//
//  CCDetail.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 16/01/15.
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

#import "CCDetail.h"
#import "AppDelegate.h"
#import "CCMain.h"
#import "NCBridgeSwift.h"


#define TOOLBAR_HEIGHT 49.0f

#define alertRequestPasswordPDF 1

@interface CCDetail () <CCActionsDeleteDelegate>
{
    AppDelegate *appDelegate;
    
    UIToolbar *_toolbar;
    
    UIBarButtonItem *_buttonAction;
    UIBarButtonItem *_buttonShare;
    UIBarButtonItem *_buttonDelete;
    
    NSInteger _indexNowVisible;
    NSString *_fileIDNowVisible;

    BOOL _reload;
    
    NSMutableOrderedSet *_dataSourceDirectoryID;
}
@end

@implementation CCDetail

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];

        self.metadataDetail = [[tableMetadata alloc] init];
        self.photos = [[NSMutableArray alloc] init];
        self.thumbs = [[NSMutableArray alloc] init];
        self.dataSourceImagesVideos = [[NSMutableArray alloc] init];
        _dataSourceDirectoryID = [[NSMutableOrderedSet alloc] init];
        _indexNowVisible = -1;
        _fileIDNowVisible = nil;
        
        app.activeDetail = self;
    }
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(insertGeocoderLocation:) name:@"insertGeocoderLocation" object:nil];

    self.imageBackground.image = [UIImage imageNamed:@"backgroundDetail"];
    
    if ([self.metadataDetail.fileName length] > 0 || [self.metadataDetail.directoryID length] > 0 || [self.metadataDetail.fileID length] > 0) {
    
        // open view
        [self viewFile];
    }
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.splitViewController.isCollapsed) {
        
        self.tabBarController.tabBar.hidden = YES;
        self.tabBarController.tabBar.translucent = YES;
    }
    
    if (self.splitViewController.isCollapsed)
        [app plusButtonVisibile:false];
}

// E' scomparso
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // remove all
    if (self.isMovingFromParentViewController)
        [self removeAllView];    
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
    }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

// remove all view
- (void)removeAllView
{
    // Audio
    if (appDelegate.player)
        [appDelegate.player removeFromSuperview];
        
    // Document
    if (_webView) {
            
        [_webView removeFromSuperview];
        _webView = nil;
    }
        
    // PDF
    if (_readerPDFViewController) {
            
        [_readerPDFViewController.view removeFromSuperview];
        _readerPDFViewController.delegate = nil;
        _readerPDFViewController = nil;
    }
        
    // Photo-Video
    if (_photoBrowser) {
            
        [_photos removeAllObjects];
        [_thumbs removeAllObjects];
        _photoBrowser.delegate = nil;
        _photoBrowser = nil;
    }
    
    [self.navigationController popToRootViewControllerAnimated:NO];
    self.navigationController.navigationBarHidden = YES;
}

- (void)changeToDisplayMode
{
    if (_readerPDFViewController)
        [self.readerPDFViewController updateContentViews];
}

- (void)createToolbar
{
    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - TOOLBAR_HEIGHT, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
    
    UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    UIBarButtonItem *fixedSpaceMini = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
    fixedSpaceMini.width = 25;
    
    _buttonAction = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"actionSheetOpenIn"] style:UIBarButtonItemStylePlain target:self action:@selector(actionButtonPressed:)];
    _buttonShare  = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"actionSheetShare"] style:UIBarButtonItemStylePlain target:self action:@selector(shareButtonPressed:)];
    _buttonDelete = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteButtonPressed:)];
    
    [_toolbar setItems:[NSArray arrayWithObjects: flexible, _buttonDelete, fixedSpaceMini, _buttonShare, fixedSpaceMini, _buttonAction,  nil]];
    [_toolbar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    
    _toolbar.barTintColor = [NCBrandColor sharedInstance].tabBar;

    [self.view addSubview:_toolbar];
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [app changeTheming:self];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View File  =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewFile
{
    // verifico se esiste l'icona e se la posso creare
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, self.metadataDetail.fileID]] == NO) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
                    
            [CCGraphics createNewImageFrom:self.metadataDetail.fileID directoryUser:app.directoryUser fileNameTo:self.metadataDetail.fileID fileNamePrint:self.metadataDetail.fileNamePrint size:@"m" imageForUpload:NO typeFile:self.metadataDetail.typeFile writePreview:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
        });
    }
    
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_image] || [self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_video]) {
        
        self.edgesForExtendedLayout = UIRectEdgeAll;
        [self viewImage];
    }
    
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_audio]) {
        
        self.edgesForExtendedLayout = UIRectEdgeBottom;
        [self viewAudio];
        [self createToolbar];
        [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];

    }
    
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_document]) {
        
        NSString *ext = [[self.metadataDetail.fileNamePrint pathExtension] lowercaseString];
        
        if ([ext isEqualToString:@"pdf"]) {
            
            self.edgesForExtendedLayout = UIRectEdgeBottom;
            [self viewPDF:@""];
            [self createToolbar];
            [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];

        } else {

            self.edgesForExtendedLayout = UIRectEdgeBottom;
            [self viewDocument];
            [self createToolbar];
            [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  View Audio =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewAudio
{
    NSString *fileName;
    
    if (_sourceDirectoryLocal) {
        
        fileName = [NSString stringWithFormat:@"%@/%@", self.metadataDetail.directoryID, self.metadataDetail.fileNamePrint];
        
    } else {
        
        fileName = [NSString stringWithFormat:@"%@/%@", [CCUtility getDirectoryAudio], self.metadataDetail.fileNamePrint];
        
        [[NSFileManager defaultManager] removeItemAtPath:fileName error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, self.metadataDetail.fileID] toPath:fileName error:nil];
    }
    
    appDelegate.player.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT);
    appDelegate.player.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    appDelegate.player.nextButton.hidden = true;
    appDelegate.player.previousButton.hidden = true;
    appDelegate.player.fullscreenButton_.hidden = true;
    
    LMMediaItem *item = [[LMMediaItem alloc] initWithInfo:@{LMMediaItemInfoURLKey:[NSURL fileURLWithPath:fileName], LMMediaItemInfoContentTypeKey:@(LMMediaItemContentTypeVideo)}];
    item.title = self.metadataDetail.fileNamePrint;
    item.artist = [NCBrandOptions sharedInstance].brand;
    
    [appDelegate.player.mediaPlayer removeAllMediaInQueue];
    [appDelegate.player.mediaPlayer addMedia:item];
    [appDelegate.player.mediaPlayer play];
    
    // Info
    NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
    [songInfo setObject:app.player.mediaPlayer.nowPlayingItem.title forKey:MPMediaItemPropertyTitle];
    [songInfo setObject:app.player.mediaPlayer.nowPlayingItem.artist forKey:MPMediaItemPropertyArtist];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
    
    [self.view addSubview:appDelegate.player];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View Document =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDocument
{
    NSString *fileName;
    
    if (_sourceDirectoryLocal) {
        
        fileName = [NSString stringWithFormat:@"%@/%@", self.metadataDetail.directoryID, self.metadataDetail.fileNamePrint];
        
    } else {
        
        fileName = [NSTemporaryDirectory() stringByAppendingString:self.metadataDetail.fileNamePrint];
        
        [[NSFileManager defaultManager] removeItemAtPath:fileName error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, self.metadataDetail.fileID] toPath:fileName error:nil];
    }
    
    NSString *ext=@"";
    ext = [CCUtility getExtension:self.metadataDetail.fileNamePrint];
    
    WKPreferences *wkPreferences = [[WKPreferences alloc] init];
    wkPreferences.javaScriptEnabled = false;
    WKWebViewConfiguration *wkConfig = [[WKWebViewConfiguration alloc] init];
    wkConfig.preferences = wkPreferences;

    self.webView = [[WKWebView alloc] initWithFrame:(CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT)) configuration:wkConfig];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self.webView setBackgroundColor:[UIColor whiteColor]];
    [self.webView setOpaque:NO];
    
    if ( [ext isEqualToString:@"CSS"] || [ext isEqualToString:@"PY"] || [ext isEqualToString:@"XML"] || [ext isEqualToString:@"JS"] ) {
        
        NSMutableURLRequest *headRequest = [NSMutableURLRequest requestWithURL:[NSURL fileURLWithPath:fileName]];
        [headRequest setHTTPMethod:@"HEAD"];
        NSHTTPURLResponse *headResponse;
        NSError *error = nil;
        [NSURLConnection sendSynchronousRequest:headRequest returningResponse:&headResponse error:&error];
        if (error != nil) {
            NSLog(@"[LOG] loadURLWithString %@",[error localizedDescription]);
        }
        
        NSString *dataFile = [[NSString alloc] initWithData:[NSData dataWithContentsOfURL:[NSURL fileURLWithPath:fileName]] encoding:NSASCIIStringEncoding];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            [self.webView  loadHTMLString:[NSString stringWithFormat:@"<div style='font-size:%@;font-family:%@;'><pre>%@",@"40",@"Sans-Serif",dataFile] baseURL:nil];
        }else{
            [self.webView  loadHTMLString:[NSString stringWithFormat:@"<div style='font-size:%@;font-family:%@;'><pre>%@",@"20",@"Sans-Serif",dataFile] baseURL:nil];
        }
        
    } else if ([ext isEqualToString:@"TXT"] ) {
        
        NSMutableURLRequest *headRequest = [NSMutableURLRequest requestWithURL:[NSURL fileURLWithPath:fileName]];
        [headRequest setHTTPMethod:@"HEAD"];
        NSHTTPURLResponse *headResponse;
        NSError *error = nil;
        [NSURLConnection sendSynchronousRequest:headRequest returningResponse:&headResponse error:&error];
        if (error != nil) {
            NSLog(@"[LOG] loadURLWithString %@",[error localizedDescription]);
        }
        
        [self.webView loadRequest:[NSMutableURLRequest requestWithURL:[NSURL fileURLWithPath:fileName]]];
    } else {
        
        [self.webView loadRequest:[NSMutableURLRequest requestWithURL:[NSURL fileURLWithPath:fileName]]];
    }
    
    [self.view addSubview:self.webView];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View Image =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewImage
{
    self.photoBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    _reload = NO;
    _indexNowVisible = -1;
    _fileIDNowVisible = nil;
    
    [self.photos removeAllObjects];
    [self.thumbs removeAllObjects];
    [_dataSourceDirectoryID removeAllObjects];
    
    // if not images, exit
    if ([self.dataSourceImagesVideos count] == 0) return;
    
    NSUInteger index = 0;
    for (tableMetadata *metadata in self.dataSourceImagesVideos) {
        
        // start from here ?
        if (self.metadataDetail.fileID && [metadata.fileID isEqualToString:self.metadataDetail.fileID])
            [self.photoBrowser setCurrentPhotoIndex:index];
        
        if (metadata.cryptated) {
            
            [self.photos addObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewDownloadCrypto"]]];
            [self.thumbs addObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewDownloadCrypto"]]];
            
        } else {
            
            [self.photos addObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewDownload"]]];
            
            MWPhoto *thumb = [MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewDownload"]];
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video]) thumb.isVideo = YES;
            [self.thumbs addObject:thumb];
        }
        
        // add directory
        [_dataSourceDirectoryID addObject:metadata.directoryID];
        index++;
    }
    
    // PhotoBrowser
    self.photoBrowser.displayActionButton = YES;
    self.photoBrowser.displayDeleteButton = YES;
    self.photoBrowser.displayNavArrows = YES;
    self.photoBrowser.displaySelectionButtons = NO;
    self.photoBrowser.alwaysShowControls = NO;
    self.photoBrowser.zoomPhotosToFill = NO;
    self.photoBrowser.startOnGrid = NO;
    self.photoBrowser.autoPlayOnAppear = NO;
    self.photoBrowser.delayToHideElements = 15;
    self.photoBrowser.enableGrid = YES;
    
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        
        [self addChildViewController:self.photoBrowser];
        [self.view addSubview:self.photoBrowser.view];
        [self.photoBrowser didMoveToParentViewController:self];
        
    } else {
        
        [self.navigationController pushViewController:self.photoBrowser animated:NO];
    }
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser
{
    return [self.dataSourceImagesVideos count];
}

- (NSString *)photoBrowser:(MWPhotoBrowser *)photoBrowser titleForPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    
    NSString *titleDir = metadata.fileNamePrint;
    self.title = titleDir;
    
    return titleDir;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index
{
    if (index != _indexNowVisible) {
    
        tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    
        NSString *directory;
        NSString *fileID = metadata.fileID;
    
        _indexNowVisible = index;
        _fileIDNowVisible = metadata.fileID;
    
        photoBrowser.toolbar.hidden = NO;
    
        
    
        if (_sourceDirectoryLocal)
            directory = self.metadataDetail.directoryID;
        else
            directory = app.directoryUser;

        // Download
        if (fileID) {
        
            metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
            if (metadata && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directory, metadata.fileID]] == NO && [metadata.session length] == 0)
                [self performSelector:@selector(downloadPhotoBrowser:) withObject:metadata afterDelay:0.1];
        
            // Title
            if (metadata && !photoBrowser.isGridController)
                self.title = metadata.fileNamePrint;
        }
    }
    
    if (_reload) {
        
        [self.photoBrowser performSelector:@selector(reloadData) withObject:nil];
        _reload = NO;
    }
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index
{
    NSString *directory;
    UIImage *image;
    
    if (_sourceDirectoryLocal)
        directory = self.metadataDetail.directoryID;
    else
        directory = app.directoryUser;

    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    
    //NSLog(@"[LOG] photoBrowser: photoAtIndex : %lu ---- di totali photo : %lu", (unsigned long)index, (unsigned long)_photos.count);
    
    if (index < self.photos.count) {
        
        if (metadata.fileID) {
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image]) {
                
                NSString *fileImage = [NSString stringWithFormat:@"%@/%@", directory, metadata.fileID];
                NSString *ext = [CCUtility getExtension:metadata.fileNamePrint];
                
                if ([ext isEqualToString:@"GIF"]) image = [UIImage animatedImageWithAnimatedGIFURL:[NSURL fileURLWithPath:fileImage]];
                else image = [UIImage imageWithContentsOfFile:fileImage];
                
                if (image) {
                    
                    MWPhoto *photo = [MWPhoto photoWithImage:image];
                    
                    // Location ??
                    [self setLocationCaptionPhoto:photo fileID:metadata.fileID];
                    
                    [self.photos replaceObjectAtIndex:index withObject:photo];
                    
                } else {
                    
                    if ([metadata.sessionError length] > 0 ) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        /*
                        UIImage *imageIcon = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
                        
                        if (imageIcon)
                            image = [CCGraphics scaleImage:imageIcon toSize:self.view.bounds.size isAspectRation:YES];

                            //image = [CCGraphics blurryImage:imageIcon withBlurLevel:2 toSize:self.view.bounds.size];
                        else
                        */ 
                        
                        image = [CCGraphics drawText:[NSLocalizedString(@"_loading_", nil) stringByAppendingString:@"..."] inImage:[UIImage imageNamed:@"button1000x200"] colorText:[UIColor darkGrayColor] sizeOfFont:50];
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:image]];
                    }
                }
            }
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video]) {
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", directory, metadata.fileID]]) {
                    
                    // remove and make the simbolic link in temp
                    NSString *toPath = [NSTemporaryDirectory() stringByAppendingString:metadata.fileNamePrint];
                    
                    [[NSFileManager defaultManager] removeItemAtPath:toPath error:nil];
                    [[NSFileManager defaultManager] linkItemAtPath:[NSString stringWithFormat:@"%@/%@", directory, metadata.fileID] toPath:toPath error:nil];
                    NSURL *url = [NSURL fileURLWithPath:toPath];
                    
                    MWPhoto *video = [MWPhoto photoWithImage:[CCGraphics thumbnailImageForVideo:url atTime:1.0]];
                    video.videoURL = url;
                    
                    [self.photos replaceObjectAtIndex:index withObject:video];
                    
                } else {
                    
                    if ([metadata.sessionError length] > 0 ) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[CCGraphics drawText:[NSLocalizedString(@"_loading_", nil) stringByAppendingString:@"..."] inImage:[UIImage imageNamed:@"button1000x200"] colorText:[UIColor darkGrayColor] sizeOfFont:50]]];
                    }
                }
            }
        }
        
        // energy saving memory
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            int iPrev = (int)index - 2;
            if (iPrev >= 0) {
                if ([self.photos objectAtIndex:iPrev] != nil)
                    [self.photos replaceObjectAtIndex:iPrev withObject:[MWPhoto photoWithImage:nil]];
            }
        
            int iNext = (int)index + 2;
            if (iNext < _photos.count) {
                if ([self.photos objectAtIndex:iNext] != nil)
                    [self.photos replaceObjectAtIndex:iNext withObject:[MWPhoto photoWithImage:nil]];
            }
        });
        
        return [self.photos objectAtIndex:index];
    }
    
    return nil;
}

- (void)gridWillAppear:(MWPhotoBrowser *)photoBrowser
{
    // reload [BUG]
    [self.photoBrowser reloadData];
    
    // in grid clear all MWPhoto : energy saving memory
    if (self.photos.count > 1 && [self.dataSourceImagesVideos count] > 0) {
        for(int index=0; index < self.photos.count; index++)
            [_photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:nil]];
    }
    
    self.title = [NSString stringWithFormat:@"Album %lu %@", (unsigned long)_photos.count,  NSLocalizedString(@"photos", nil)];
}

- (void)gridWillDisappear:(MWPhotoBrowser *)photoBrowser
{    
    //
    photoBrowser.toolbar.hidden = NO;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser thumbPhotoAtIndex:(NSUInteger)index
{
    NSString *directory;
    
    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    
    if (_sourceDirectoryLocal)
        directory = self.metadataDetail.directoryID;
    else
        directory = app.directoryUser;

    if (index < self.thumbs.count) {
        
        if (metadata.fileID) {
            
            UIImage *image;
            
            if (_sourceDirectoryLocal) {
                
                image = [CCGraphics createNewImageFrom:metadata.fileID directoryUser:directory fileNameTo:metadata.fileID fileNamePrint:metadata.fileNamePrint size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:NO optimizedFileName:[CCUtility getOptimizedPhoto]];
                
            } else {
                
                NSString *fileImage = [NSString stringWithFormat:@"%@/%@.ico", directory, metadata.fileID];
                
                image = [UIImage animatedImageWithAnimatedGIFURL:[NSURL fileURLWithPath:fileImage]];
            }
            
            if (image) {
                
                MWPhoto *thumb = [MWPhoto photoWithImage:image];
                if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video]) thumb.isVideo = YES;
                [self.thumbs replaceObjectAtIndex:index withObject:thumb];
            }
        }
        return [self.thumbs objectAtIndex:index];
    }
    
    return nil;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser actionButtonPressedForPhotoAtIndex:(NSUInteger)index
{
    NSString *filePath;

    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    if (metadata == nil) return;
    
    if (_sourceDirectoryLocal) {
        
        filePath = [NSString stringWithFormat:@"%@/%@", self.metadataDetail.directoryID, self.metadataDetail.fileNamePrint];
        
    } else {
        
        filePath = [NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileNamePrint];
        
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID] toPath:filePath error:nil];
    }
    
    self.docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:filePath]];
    
    self.docController.delegate = self;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) [self.docController presentOptionsMenuFromRect:photoBrowser.view.frame inView:photoBrowser.view animated:YES];
    [self.docController presentOptionsMenuFromBarButtonItem:photoBrowser.actionButton animated:YES];
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser shareButtonPressedForPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    
    [app.activeMain openWindowShare:metadata];
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser deleteButtonPressedForPhotoAtIndex:(NSUInteger)index deleteButton:(UIBarButtonItem *)deleteButton
{
    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    if (metadata == nil || [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, metadata.fileID]] == NO) {
        
        [app messageNotification:@"_info_" description:@"_file_not_found_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
        
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil)
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           [[CCActions sharedInstance] deleteFileOrFolder:metadata delegate:self];
                                                       }]];

    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil)
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                            [alertController dismissViewControllerAnimated:YES completion:nil];
                                                       }]];
    
    alertController.popoverPresentationController.barButtonItem = deleteButton;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self.parentViewController presentViewController:alertController animated:YES completion:NULL];
}

- (void)triggerProgressTask:(NSNotification *)notification
{
    NSDictionary *dict = notification.userInfo;
    float progress = [[dict valueForKey:@"progress"] floatValue];
    
    if (progress == 0)
        [self.navigationController cancelCCProgress];
    else
        [self.navigationController setCCProgressPercentage:progress*100 andTintColor:[NCBrandColor sharedInstance].navigationBarProgress];
}

- (void)downloadPhotoBrowserFailure:(NSInteger)errorCode
{
    [app messageNotification:@"_download_selected_files_" description:@"_error_download_photobrowser_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];

    [self.photoBrowser reloadData];
}

- (void)downloadPhotoBrowserSuccess:(tableMetadata *)metadataVar selector:(NSString *)selector
{
    NSUInteger index = 0;
    
    // if a message for a directory of these
    if (![_dataSourceDirectoryID containsObject:metadataVar.directoryID])
        return;
    
    for (NSUInteger i=0; i < [self.dataSourceImagesVideos count]; i++ ) {
        
        tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:i];
        
        // search index
        if ([metadataVar.fileID isEqualToString:metadata.fileID]) {
            
            index = i;
            break;
        }
    }
    
    // do not reload is Video on air
    if (_photoBrowser.currentVideoPlayerViewController.isViewLoaded && _photoBrowser.currentVideoPlayerViewController.view.window) return;
    
    //NSLog(@"[LOG] Add Download Photo Browser");
    
    if ([metadataVar.fileID isEqualToString:_fileIDNowVisible] || [self.photoBrowser isGridReload:index]) {
        
        [self.photoBrowser reloadData];
        
        _reload = NO;
            
    } else {
        
        _reload = YES;
    }    
}

- (void)downloadPhotoBrowser:(tableMetadata *)metadata
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    
    [[CCNetworking sharedNetworking] downloadFile:metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorLoadViewImage selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:nil];
}

- (void)insertGeocoderLocation:(NSNotification *)notification
{
    if (notification.userInfo.count == 0)
        return;
    
    NSString *fileID = [[notification.userInfo allKeys] objectAtIndex:0];
    //NSDate *date = [[notification.userInfo allValues] objectAtIndex:0];
 
    // test [Chrash V 1.14,15]
    if (_indexNowVisible >= [self.photos count])
        return;
    
    if ([fileID isEqualToString:_fileIDNowVisible]) {
            
        MWPhoto *photo = [self.photos objectAtIndex:_indexNowVisible];
            
        [self setLocationCaptionPhoto:photo fileID:fileID];
            
        if (![self.photoBrowser isGridController]) {
            
            //[self.photoBrowser hideControls];
            //[self.photoBrowser showControls];
        }
    }
}

- (void)setLocationCaptionPhoto:(MWPhoto *)photo fileID:(NSString *)fileID
{
    tableLocalFile *localFile;

    // read Geocoder
    localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
    
    if ([localFile.exifLatitude doubleValue] != 0 || [localFile.exifLongitude doubleValue] != 0) {
        
        // Fix BUG Geo latitude & longitude
        if ([localFile.exifLatitude doubleValue] == 9999 || [localFile.exifLongitude doubleValue] == 9999) {
            
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
            if (metadata) {
                [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata directoryUser:app.directoryUser activeAccount:app.activeAccount];
            }
        }
        
        [[CCExifGeo sharedInstance] setGeocoderEtag:fileID exifDate:localFile.exifDate latitude:localFile.exifLatitude longitude:localFile.exifLongitude];
        
        localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
        if ([localFile.exifLatitude floatValue] != 0 || [localFile.exifLongitude floatValue] != 0) {
                        
            NSString *location = [[NCManageDatabase sharedInstance] getLocationFromGeoLatitude:localFile.exifLatitude longitude:localFile.exifLongitude];
            
            if ([localFile.exifDate isEqualToDate:[NSDate distantPast]] == NO && location) {
                
                NSString *localizedDateTime = [NSDateFormatter localizedStringFromDate:localFile.exifDate dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterMediumStyle];
                
                photo.caption = [NSString stringWithFormat:NSLocalizedString(@"%@\n%@", nil), localizedDateTime, location];
            }
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  View PDF =====
#pragma --------------------------------------------------------------------------------------------

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
    
    [[alertView textFieldAtIndex:0] resignFirstResponder];
    
    if (alertView.tag == alertRequestPasswordPDF) [self performSelector:@selector(viewPDF:) withObject:[alertView textFieldAtIndex:0].text afterDelay:0.3];
}

- (void)viewPDF:(NSString *)password
{
    NSString *fileName;
    
    if (_sourceDirectoryLocal) {
        
        fileName = [NSString stringWithFormat:@"%@/%@", self.metadataDetail.directoryID, self.metadataDetail.fileNamePrint];
        
    } else {
        
        fileName = [NSTemporaryDirectory() stringByAppendingString:self.metadataDetail.fileNamePrint];
        
        [[NSFileManager defaultManager] removeItemAtPath:fileName error:nil];
        [[NSFileManager defaultManager] linkItemAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, self.metadataDetail.fileID] toPath:fileName error:nil];
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileName isDirectory:nil] == NO) {
        
        // read file error
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_read_file_error_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
    }
    
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)[NSURL fileURLWithPath:fileName]);
    
    if (pdf) {
        
        // Encrypted
        if (CGPDFDocumentIsEncrypted(pdf) == YES) {
            
            // Try a blank password first, per Apple's Quartz PDF example
            if (CGPDFDocumentUnlockWithPassword(pdf, "") == YES) {
                
                // blank password
                [self readerPDF:fileName password:@""];
                
            } else {
                
                if ([password length] == 0) {
                    
                    // password request
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_insert_password_pfd_",nil) message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                    [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
                    alertView.tag = alertRequestPasswordPDF;
                    [alertView show];
                    
                } else {
                    
                    const char *key = [password UTF8String];
                    
                    // failure
                    if (CGPDFDocumentUnlockWithPassword(pdf, key) == NO) {
                        
                        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_password_pdf_error_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                        [alertView show];
                        
                    } else {
                        
                        // pdf with password
                        [self readerPDF:fileName password:password];
                    }
                }
            }
            
        } else{
            
            // No password
            [self readerPDF:fileName password:@""];
        }
        
    } else {
        
        // read file error
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_read_file_error_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
    }
}

- (void)readerPDF:(NSString *)fileName password:(NSString *)password
{
    ReaderDocument *documentPDF = [ReaderDocument withDocumentFilePath:fileName password:password];
    
    if (documentPDF != nil) {
        
        self.readerPDFViewController = [[ReaderViewController alloc] initWithReaderDocument:documentPDF];
        self.readerPDFViewController.delegate = self;
        self.readerPDFViewController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT);
        [self.readerPDFViewController updateContentViews];

        [self addChildViewController:self.readerPDFViewController];
        [self.view addSubview:self.readerPDFViewController.view];
        [self.readerPDFViewController didMoveToParentViewController:self];
        
    } else {
        
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_read_file_error_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
        [alertView show];
        
    }
}

- (void)handleSingleTapReader
{
    self.navigationController.navigationBarHidden = !self.navigationController.navigationBarHidden;
    _toolbar.hidden = !_toolbar.isHidden;
    
    if (_toolbar.isHidden) {
        self.readerPDFViewController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    } else {
        self.readerPDFViewController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT);
    }
    [self.readerPDFViewController updateContentViews];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFileOrFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"[LOG] delete failure");
}

- (void)deleteFileOrFolderSuccess:(CCMetadataNet *)metadataNet
{
    // reload Main
    [app.activeMain reloadDatasource];
    
    // If removed document (web) or PDF close
    if (_webView || _readerPDFViewController)
        [self removeAllView];
        
    // if a message for a directory of these
    if (![_dataSourceDirectoryID containsObject:metadataNet.directoryID])
        return;
    
    // if we are not in browserPhoto and it's removed photo/video in preview then "< Back"
    if (!self.photoBrowser && [self.metadataDetail.fileID isEqualToString:metadataNet.fileID]) {
        
        [app.player.mediaPlayer stop];
        
        NSArray *viewsToRemove = [self.view subviews];
        for (id element in viewsToRemove) {
            
            if ([element isMemberOfClass:[UIView class]] || [element isMemberOfClass:[UIToolbar class]] || [element isMemberOfClass:[LMMediaPlayerView class]])
                [element removeFromSuperview];
        }
        
        self.title = @"";
        
        [self.navigationController popViewControllerAnimated:YES];
        
    } else {
    
        // only photoBrowser if exists
        for (NSUInteger index=0; index < [self.dataSourceImagesVideos count] && _photoBrowser; index++ ) {
        
            tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
        
            // ricerca index
            if ([metadata.fileID isEqualToString:metadataNet.fileID]) {
            
                [self.dataSourceImagesVideos removeObjectAtIndex:index];
            
                [self.photos removeObjectAtIndex:index];
                [self.thumbs removeObjectAtIndex:index];
            
                [self.photoBrowser reloadData];
            
                // Title
                if ([self.dataSourceImagesVideos count] == 0) {
                
                    self.title = @"";
                    [self.navigationController popViewControllerAnimated:YES];
                }
            
                break;
            }
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== ButtonPressed =====
#pragma --------------------------------------------------------------------------------------------

- (void)actionButtonPressed:(UIBarButtonItem *)sender
{    
    NSString *filePath;
    
    if ([self.metadataDetail.fileNamePrint length] == 0) return;
    
    if (_sourceDirectoryLocal) {
        
        filePath = [NSString stringWithFormat:@"%@/%@", self.metadataDetail.directoryID, self.metadataDetail.fileNamePrint];
        
    } else {
        
        filePath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), self.metadataDetail.fileNamePrint];
    }
    
    self.docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:filePath]];

    self.docController.delegate = self;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) [self.docController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES];
    [self.docController presentOptionsMenuFromBarButtonItem:sender animated:YES];
}

- (void)shareButtonPressed:(UIBarButtonItem *)sender
{
    [app.activeMain openWindowShare:self.metadataDetail];
}

- (void)deleteButtonPressed:(UIBarButtonItem *)sender
{
    if ([self.metadataDetail.fileNamePrint length] == 0) return;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil)
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           [[CCActions sharedInstance] deleteFileOrFolder:self.metadataDetail delegate:self];
                                                       }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil)
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                           [alertController dismissViewControllerAnimated:YES completion:nil];
                                                       }]];
    
    alertController.popoverPresentationController.barButtonItem = _buttonDelete;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];

    [self presentViewController:alertController animated:YES completion:NULL];
}

@end

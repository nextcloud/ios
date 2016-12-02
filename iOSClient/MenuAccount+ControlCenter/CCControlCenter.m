//
//  CCControlCenter.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 07/04/16.
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

#import "CCControlCenter.h"

#import "AppDelegate.h"
#import "CCMain.h"
#import "CCDetail.h"

#define BORDER_TOUCH_UPDOWN 50.0f

#define TOOLBAR_TRANSFER_H 0.0f
#define TOOLBAR_ADD_BORDER 20.0f

#define SIZE_FONT_NORECORD 18.0f

#define ANIMATION_GESTURE 0.50f

#define download 1
#define downloadwwan 2
#define upload 3
#define uploadwwan 4

@interface CCControlCenter ()
{
    UIVisualEffectView *_mainView;
    UITableView *_tableView;
    UILabel *_noRecord;
    //UIToolbar *_toolbarTask;
    UIImageView *_imageDrag;
    UIView *_endLine;
    
    CGFloat start, stop;
    
    UIPanGestureRecognizer *panNavigationBar, *panImageDrag;
    UITapGestureRecognizer *_singleFingerTap;
    
    // Datasource
    CCSectionDataSource *_sectionDataSource;
}
@end

@implementation CCControlCenter

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    _mainView = [[UIVisualEffectView alloc] initWithEffect:effect];
    [_mainView setFrame:CGRectMake(0, 0, self.navigationBar.frame.size.width, 0)];
    _mainView.hidden = YES;
    
    // TEST
    //_mainView.backgroundColor = [UIColor yellowColor];
        
    _tableView = [[UITableView alloc] init];
    [_tableView setFrame:CGRectMake(0, 0, self.navigationBar.frame.size.width, 0)];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_tableView registerNib:[UINib nibWithNibName:@"CCControlCenterCell" bundle:nil] forCellReuseIdentifier:@"CCControlCenterCell"];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];

    [_mainView addSubview:_tableView];
    
    _noRecord =[[UILabel alloc]init];
    _noRecord.backgroundColor=[UIColor clearColor];
    _noRecord.textColor = COLOR_BRAND;
    _noRecord.font = [UIFont systemFontOfSize:SIZE_FONT_NORECORD];
    _noRecord.textAlignment = NSTextAlignmentCenter;
    _noRecord.text = NSLocalizedString(@"_no_transfer_",nil);

    [_mainView addSubview:_noRecord];
    
    /*
    _toolbarTask = [[UIToolbar alloc] init];
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"toolbarTaskCancel"] style:UIBarButtonItemStylePlain target:self action:@selector(cancelAllTask)];
    UIBarButtonItem *stopItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"toolbarTaskStop"] style:UIBarButtonItemStylePlain target:self action:@selector(stopAllTask)];
    UIBarButtonItem *reloadItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"toolbarTaskReload"] style:UIBarButtonItemStylePlain target:self action:@selector(reloadAllTask)];
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    [_toolbarTask setItems:[[NSArray alloc] initWithObjects:cancelItem, spacer, stopItem, spacer, reloadItem, nil]];
    [_toolbarTask setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    [_toolbarTask setBackgroundImage:[UIImage new] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    [_toolbarTask setShadowImage:[UIImage new] forToolbarPosition:UIBarPositionAny];
    
    [_mainView addSubview:_toolbarTask];
    */
    
    _imageDrag = [[UIImageView alloc] init];
    [_imageDrag setFrame:CGRectMake(0, 0, self.navigationBar.frame.size.width, 0)];
    _imageDrag.image = [UIImage imageNamed:image_drag];
    _imageDrag.contentMode =  UIViewContentModeCenter;
    _imageDrag.userInteractionEnabled = YES;

    [_mainView addSubview:_imageDrag];
    
    _endLine = [[UIView alloc] init];
    [_endLine setFrame:CGRectMake(0, 0, self.navigationBar.frame.size.width, 0)];
    _endLine.backgroundColor = COLOR_BRAND;

    [_mainView addSubview:_endLine];
    
    [self.navigationBar.superview insertSubview:_mainView belowSubview:self.navigationBar];
    
    // Pop Gesture Recognizer
    [self.interactivePopGestureRecognizer addTarget:self action:@selector(handlePopGesture:)];
    
    panImageDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panImageDrag.maximumNumberOfTouches = panImageDrag.minimumNumberOfTouches = 1;
    
    [_imageDrag addGestureRecognizer:panImageDrag];
   
    panNavigationBar = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panNavigationBar.maximumNumberOfTouches = panNavigationBar.minimumNumberOfTouches = 1;
    
    [self.navigationBar addGestureRecognizer:panNavigationBar];
    
    [self reloadDatasource];
}

/* iOS Developer Library : A panning gesture is continuous. It begins (UIGestureRecognizerStateBegan) when the minimum number of fingers allowed (minimumNumberOfTouches) has moved enough to be considered a pan. It changes (UIGestureRecognizerStateChanged) when a finger moves while at least the minimum number of fingers are pressed down. It ends (UIGestureRecognizerStateEnded) when all fingers are lifted. */

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture;
{
    CGPoint currentPoint = [gesture locationInView:self.view];
    CGFloat navigationBarH = self.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat navigationBarW = self.navigationBar.frame.size.width;
    CGFloat heightScreen = [UIScreen mainScreen].bounds.size.height - self.tabBarController.tabBar.frame.size.height;
    CGFloat heightTableView = [UIScreen mainScreen].bounds.size.height - self.tabBarController.tabBar.frame.size.height - navigationBarH - BORDER_TOUCH_UPDOWN - TOOLBAR_TRANSFER_H - TOOLBAR_ADD_BORDER;

    float centerMaxH = [self getMaxH] / 2;
    float step = [self getMaxH] / 10;
    float tableViewY = navigationBarH;
    
    // BUG Scroll to top of UITableView by tapping status bar
    _mainView.hidden = NO;
    
    // start
    if (gesture.state == UIGestureRecognizerStateBegan) {
     
        start = currentPoint.y;
    }
    
    // cancelled (return to 0)
    if (gesture.state == UIGestureRecognizerStateCancelled) {
        
        currentPoint.y = 0;
        tableViewY = 0;
        panNavigationBar.enabled = YES;
    }

    // end
    if (gesture.state == UIGestureRecognizerStateEnded) {
        
        stop = currentPoint.y;
        
        // DOWN
        if (start < stop) {
        
            if (stop < (start + step + navigationBarH) && start <= navigationBarH) {
                currentPoint.y = 0;
                tableViewY = 0;
                panNavigationBar.enabled = YES;
            } else {
                currentPoint.y = [self getMaxH];
                tableViewY = navigationBarH;
                panNavigationBar.enabled = NO;
            }
        }
        
        // UP
        if (start >= stop && start >= navigationBarH) {
            
            if (stop > (start - step)) {
                currentPoint.y = [self getMaxH];
                tableViewY = navigationBarH;
                panNavigationBar.enabled = NO;
            } else {
                currentPoint.y = 0;
                tableViewY = 0;
                panNavigationBar.enabled = YES;
            }
        }
    }
    
    // changed
    if (gesture.state == UIGestureRecognizerStateChanged) {
        
        if (currentPoint.y <= navigationBarH) {
            currentPoint.y = 0;
            tableViewY = 0;
        }
        else if (currentPoint.y >= [self getMaxH]) {
            currentPoint.y = [self getMaxH];
            tableViewY = navigationBarH;
        }
        else {
            if (currentPoint.y - navigationBarH < navigationBarH) tableViewY = currentPoint.y - navigationBarH;
            else tableViewY = navigationBarH;
        }
    }
    
    [UIView animateWithDuration:ANIMATION_GESTURE delay:0.0 options:UIViewAnimationOptionTransitionCrossDissolve
        animations:^ {
        
            _mainView.frame = CGRectMake(0, 0, navigationBarW, currentPoint.y);
            //_tableView.frame = CGRectMake(0, tableViewY, navigationBarW, _mainView.frame.size.height - tableViewY - BORDER_TOUCH_UPDOWN - TOOLBAR_TRANSFER_H - TOOLBAR_ADD_BORDER);
            _tableView.frame = CGRectMake(0, currentPoint.y - heightScreen + navigationBarH, navigationBarW, heightTableView);
            _noRecord.frame = CGRectMake(0, currentPoint.y - centerMaxH - TOOLBAR_TRANSFER_H, navigationBarW, SIZE_FONT_NORECORD+10);
            //_toolbarTask.frame = CGRectMake(0, currentPoint.y - BORDER_TOUCH_UPDOWN - TOOLBAR_TRANSFER_H - TOOLBAR_ADD_BORDER/2, _mainView.frame.size.width, TOOLBAR_TRANSFER_H);
            _imageDrag.frame = CGRectMake(0, currentPoint.y - BORDER_TOUCH_UPDOWN, navigationBarW, BORDER_TOUCH_UPDOWN);
            _endLine.frame = CGRectMake(0, currentPoint.y - BORDER_TOUCH_UPDOWN, navigationBarW, 1);
        
        } completion:^ (BOOL completed) {
            
            if (_mainView.frame.size.height == [self getMaxH]) {
                [self setIsOpen:YES];
            } else {
                [self setIsOpen:NO];
            }
            
            // BUG Scroll to top of UITableView by tapping status bar
            if (_mainView.frame.size.height == 0)
                _mainView.hidden = YES;
        }
    ];
}

/* iOS Developer Library : The navigation controller installs this gesture recognizer on its view and uses it to pop the topmost view controller off the navigation stack. You can use this property to retrieve the gesture recognizer and tie it to the behavior of other gesture recognizers in your user interface. When tying your gesture recognizers together, make sure they recognize their gestures simultaneously to ensure that your gesture recognizers are given a chance to handle the event. */

- (void)handlePopGesture:(UIGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _isPopGesture = YES;
    }
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        _isPopGesture = NO;
    }
}

//  rotazione
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    if (_isOpen) {
    
        [self setControlCenterHidden:YES];
    
        [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
            [self openControlCenterToSize:size];
        
            [self setControlCenterHidden: self.navigationBarHidden];
        }];
        
        //[self closeControlCenter];
    }
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)setControlCenterHidden:(BOOL)hidden
{
    _mainView.hidden = hidden;
}

- (float)getMaxH
{
    //return ([UIScreen mainScreen].bounds.size.height / 4) * 3;
    
    return [UIScreen mainScreen].bounds.size.height - self.tabBarController.tabBar.frame.size.height;
}

- (void)openControlCenterToSize:(CGSize)size
{
    CGFloat navigationBarH = self.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;
    
    _mainView.frame = CGRectMake(0, 0, size.width, [self getMaxH]);
    _tableView.frame = CGRectMake(0, navigationBarH, _mainView.frame.size.width, _mainView.frame.size.height - navigationBarH - BORDER_TOUCH_UPDOWN - TOOLBAR_TRANSFER_H - TOOLBAR_ADD_BORDER);
    _noRecord.frame = CGRectMake(0, _mainView.frame.size.height / 2 - TOOLBAR_TRANSFER_H, _mainView.frame.size.width, SIZE_FONT_NORECORD+10);
    //_toolbarTask.frame = CGRectMake(0, _mainView.frame.size.height - BORDER_TOUCH_UPDOWN - TOOLBAR_TRANSFER_H - TOOLBAR_ADD_BORDER/2, _mainView.frame.size.width, TOOLBAR_TRANSFER_H);
    _imageDrag.frame = CGRectMake(0, _mainView.frame.size.height - BORDER_TOUCH_UPDOWN, _mainView.frame.size.width, BORDER_TOUCH_UPDOWN);
    _endLine.frame = CGRectMake(0, _mainView.frame.size.height - BORDER_TOUCH_UPDOWN, _mainView.frame.size.width, 1);
    
    panNavigationBar.enabled = NO;
    [self setIsOpen:YES];
}

/*
 - (void)closeControlCenterToSize:(CGSize)size
 {
 _mainView.frame = CGRectMake(0, 0, size.width, 0);
 _tableView.frame = CGRectMake(0, 0, _mainView.frame.size.width, 0);
 _noRecord.frame = CGRectMake(0, 0, _mainView.frame.size.width, 0);
 _imageDrag.frame = CGRectMake(0, 0, _mainView.frame.size.width, 0);
 _endLine.frame = CGRectMake(0, 0, _mainView.frame.size.width, 0);
 
 panNavigationBar.enabled = YES;
 }
 */

- (void)setIsOpen:(BOOL)setOpen
{
    if (setOpen) {
        
        if (!_isOpen) {
            
            _isOpen = YES;

            [self reloadDatasource];
        }
        
    } else {
        
        _isOpen = NO;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ===== Single Finger Tap =====
#pragma --------------------------------------------------------------------------------------------

- (void)enableSingleFingerTap:(SEL)selector target:(id)target
{
    _singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:target action:selector];
    [self.navigationBar addGestureRecognizer:_singleFingerTap];
}

- (void)disableSingleFingerTap
{
    [self.navigationBar removeGestureRecognizer:_singleFingerTap];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)progressTask:(NSString *)fileID serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated progress:(float)progress;
{
    // Chech 
    if (!fileID)
        return;
    
    [app.listProgressMetadata setObject:[NSNumber numberWithFloat:progress] forKey:fileID];

    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:fileID];
    
    if (indexPath && indexPath.row == 0) {
        
        CCControlCenterCell *cell = (CCControlCenterCell *)[_tableView cellForRowAtIndexPath:indexPath];
    
        if (cryptated) cell.progressView.progressTintColor = COLOR_ENCRYPTED;
        else cell.progressView.progressTintColor = COLOR_CLEAR;
        
        cell.progressView.hidden = NO;
        [cell.progressView setProgress:progress];
        
    } else {
     
        [self reloadDatasource];
    }
}

- (void)reloadTaskButton:(id)sender withEvent:(UIEvent *)event
{
    if (app.activeMain == nil)
        return;
    
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:_tableView];
    NSIndexPath * indexPath = [_tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (metadata)
            [app.activeMain reloadTaskButton:metadata];
    }
}

- (void)reloadAllTask
{
    if (app.activeMain == nil)
        return;
    
    for (NSString *key in _sectionDataSource.allRecordsDataSource.allKeys) {
        
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:key];
        
        if ([metadata.session containsString:@"download"] && (metadata.sessionTaskIdentifierPlist != taskIdentifierDone))
            continue;
        
        if ([metadata.session containsString:@"upload"] && (metadata.sessionTaskIdentifier != taskIdentifierStop))
            continue;
        
        [app.activeMain reloadTaskButton:metadata];
    }
}

- (void)cancelTaskButton:(id)sender withEvent:(UIEvent *)event
{
    if (app.activeMain == nil)
        return;
    
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:_tableView];
    NSIndexPath * indexPath = [_tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (metadata)
            [app.activeMain cancelTaskButton:metadata reloadTable:YES];
    }
}

- (void)cancelAllTask
{
    if (app.activeMain == nil)
        return;
    
    BOOL lastAndRefresh = NO;
    
    for (NSString *key in _sectionDataSource.allRecordsDataSource.allKeys) {
        
        if ([key isEqualToString:[_sectionDataSource.allRecordsDataSource.allKeys lastObject]])
            lastAndRefresh = YES;

        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:key];
        
        if ([metadata.session containsString:@"upload"] && metadata.cryptated && ((metadata.sessionTaskIdentifier == taskIdentifierDone && metadata.sessionTaskIdentifierPlist >= 0) || (metadata.sessionTaskIdentifier >= 0 && metadata.sessionTaskIdentifierPlist == taskIdentifierDone)))
            continue;
        
        [app.activeMain cancelTaskButton:metadata reloadTable:lastAndRefresh];
    }
}

- (void)stopTaskButton:(id)sender withEvent:(UIEvent *)event
{
    if (app.activeMain == nil)
        return;
    
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:_tableView];
    NSIndexPath * indexPath = [_tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (metadata)
            [app.activeMain stopTaskButton:metadata];
    }
}

- (void)stopAllTask
{
    if (app.activeMain == nil)
        return;
    
    for (NSString *key in _sectionDataSource.allRecordsDataSource.allKeys) {
        
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:key];
        
        if ([metadata.session containsString:@"download"]) {
                [app.activeMain cancelTaskButton:metadata reloadTable:YES];
            continue;
        }
        
        if ([metadata.session containsString:@"upload"] && metadata.cryptated && ((metadata.sessionTaskIdentifier == taskIdentifierDone && metadata.sessionTaskIdentifierPlist >= 0) || (metadata.sessionTaskIdentifier >= 0 && metadata.sessionTaskIdentifierPlist == taskIdentifierDone)))
            continue;
        
        [app.activeMain stopTaskButton:metadata];
    }    
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasource
{
    if (app.activeAccount == nil || app.activeUrl == nil)
        return;
    
    if (_isOpen) {
    
        NSArray *recordsTableMetadata = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND ((session CONTAINS 'upload') OR (session CONTAINS 'download' AND (sessionSelector != 'loadPlist')))", app.activeAccount] fieldOrder:@"sessionTaskIdentifier" ascending:YES];
    
        _sectionDataSource  = [CCSection creataDataSourseSectionTableMetadata:recordsTableMetadata listProgressMetadata:app.listProgressMetadata groupByField:@"session" replaceDateToExifDate:NO activeAccount:app.activeAccount];
    
        if ([_sectionDataSource.allRecordsDataSource count] == 0) _noRecord.hidden = NO;
        else _noRecord.hidden = YES;
    }
    
    [_tableView reloadData];
    
    [app updateApplicationIconBadgeNumber];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
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
    return 13.0f;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIVisualEffectView *visualEffectView;
    
    NSString *titleSection, *numberTitle;
    NSInteger typeOfSession = 0;
    
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]]) titleSection = [_sectionDataSource.sections objectAtIndex:section];
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSDate class]]) titleSection = [CCUtility getTitleSectionDate:[_sectionDataSource.sections objectAtIndex:section]];
    
    NSArray *metadatas = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:section]];
    NSUInteger rowsCount = [metadatas count];
    
    visualEffectView = [[UIVisualEffectView alloc] init];
    visualEffectView.backgroundColor = [UIColor clearColor];
    
    // title section
    if ([titleSection isEqualToString:@"_none_"]) {
        titleSection = @"";
    } else if ([titleSection containsString:@"download"] && ![titleSection containsString:@"wwan"]) {
        typeOfSession = download;
        titleSection = NSLocalizedString(@"_title_section_download_",nil);
    } else if ([titleSection containsString:@"download"] && [titleSection containsString:@"wwan"]) {
        typeOfSession = downloadwwan;
        titleSection = [NSLocalizedString(@"_title_section_download_",nil) stringByAppendingString:@" Wi-Fi"];
    } else if ([titleSection containsString:@"upload"] && ![titleSection containsString:@"wwan"]) {
        typeOfSession = upload;
        titleSection = NSLocalizedString(@"_title_section_upload_",nil);
    } else if ([titleSection containsString:@"upload"] && [titleSection containsString:@"wwan"]) {
        typeOfSession = uploadwwan;
        titleSection = [NSLocalizedString(@"_title_section_upload_",nil) stringByAppendingString:@" Wi-Fi"];
    } else {
        titleSection = NSLocalizedString(titleSection,nil);
    }
    
    // title label on left
    UILabel *titleLabel=[[UILabel alloc]initWithFrame:CGRectMake(8, 3, 0, 13)];
    titleLabel.textColor = COLOR_GRAY;
    titleLabel.font = [UIFont systemFontOfSize:9];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.text = titleSection;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [visualEffectView addSubview:titleLabel];
    
    // element (s) on right
    UILabel *elementLabel=[[UILabel alloc]initWithFrame:CGRectMake(-8, 3, 0, 13)];
    elementLabel.textColor = COLOR_GRAY;
    elementLabel.font = [UIFont systemFontOfSize:9];
    elementLabel.textAlignment = NSTextAlignmentRight;
    elementLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    if ((typeOfSession == download && app.queueNunDownload > rowsCount) || (typeOfSession == downloadwwan && app.queueNumDownloadWWan > rowsCount) ||
        (typeOfSession == upload   && app.queueNumUpload > rowsCount)   || (typeOfSession == uploadwwan && app.queueNumUploadWWan > rowsCount)) {
        numberTitle = [NSString stringWithFormat:@"%lu+", (unsigned long)rowsCount];
    } else {
        numberTitle = [NSString stringWithFormat:@"%lu", (unsigned long)rowsCount];
    }
    
    if (rowsCount > 1)
        elementLabel.text = [NSString stringWithFormat:@"%@ %@", numberTitle, NSLocalizedString(@"_elements_",nil)];
    else
        elementLabel.text = [NSString stringWithFormat:@"%@ %@", numberTitle, NSLocalizedString(@"_element_",nil)];
    
    // view
    [visualEffectView addSubview:elementLabel];
    
    return visualEffectView;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSString *titleSection;
    NSString *element_s;
    
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]]) titleSection = [_sectionDataSource.sections objectAtIndex:section];
    
    // Prepare view for title in footer
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    
    UILabel *titleFooterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 18)];
    titleFooterLabel.textColor = COLOR_GRAY;
    titleFooterLabel.font = [UIFont systemFontOfSize:12];
    titleFooterLabel.textAlignment = NSTextAlignmentCenter;

    // Footer Download
    if ([titleSection containsString:@"download"] && ![titleSection containsString:@"wwan"] && titleSection != nil) {
        
        // element or elements ?
        if (app.queueNunDownload > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Num record to upload
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_download_", nil), app.queueNunDownload, element_s]];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    // Footer Download WWAN
    if ([titleSection containsString:@"download"] && [titleSection containsString:@"wwan"] && titleSection != nil) {
        
        // element or elements ?
        if (app.queueNumDownloadWWan > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
            
        // Add the symbol WiFi and Num record
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = [UIImage imageNamed:image_WiFiSmall];
        NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_download_wwan_", nil), app.queueNumDownloadWWan, element_s]];
        [stringFooter insertAttributedString:attachmentString atIndex:0];
        titleFooterLabel.attributedText = stringFooter;
            
        [view addSubview:titleFooterLabel];
        return view;
    }

    // Footer Upload
    if ([titleSection containsString:@"upload"] && ![titleSection containsString:@"wwan"] && titleSection != nil) {
        
        // element or elements ?
        if (app.queueNumUpload > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Num record to upload
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_upload_", nil), app.queueNumUpload, element_s]];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }

    // Footer Upload WWAN
    if ([titleSection containsString:@"upload"] && [titleSection containsString:@"wwan"] && titleSection != nil) {
        
        // element or elements ?
        if (app.queueNumUploadWWan > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Add the symbol WiFi and Num record
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = [UIImage imageNamed:image_WiFiSmall];
        NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_upload_wwan_", nil), app.queueNumUploadWWan,element_s]];
        [stringFooter insertAttributedString:attachmentString atIndex:0];
        titleFooterLabel.attributedText = stringFooter;
            
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    //NSString *titleSection;
    
    //if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]])
    //    titleSection = [_sectionDataSource.sections objectAtIndex:section];
    
    //if ([titleSection rangeOfString:@"upload"].location != NSNotFound && [titleSection rangeOfString:@"wwan"].location != NSNotFound && titleSection != nil) return 18.0f;
    //else return 0.0f;
    
    return 18.0f;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [_sectionDataSource.sections indexOfObject:title];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *dataFile;
    NSString *lunghezzaFile;
    
    NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
    
    CCControlCenterCell *cell = (CCControlCenterCell *)[tableView dequeueReusableCellWithIdentifier:@"CCControlCenterCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
    // ----------------------------------------------------------------------------------------------------------
    // DEFAULT
    // ----------------------------------------------------------------------------------------------------------
    
    cell.fileImageView.image = nil;
    cell.statusImageView.image = nil;
    
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
        
    } else {
        
        // è un file
        
        dataFile = [CCUtility dateDiff:metadata.date];
        lunghezzaFile = [CCUtility transformedSize:metadata.size];
        
        // Plist ancora da scaricare
        if (metadata.cryptated && [metadata.title length] == 0) {
            
            dataFile = @" ";
            lunghezzaFile = @" ";
        }
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // File Image View
    // ----------------------------------------------------------------------------------------------------------
    
    // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]]) {
        
        cell.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        
    } else {
        
        cell.fileImageView.image = [UIImage imageNamed:metadata.iconName];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // Image Status cyptated & Lock Passcode
    // ----------------------------------------------------------------------------------------------------------
    
    // File Cyptated
    if (metadata.cryptated && metadata.directory == NO && [metadata.type isEqualToString:metadataType_model] == NO) {
        
        cell.statusImageView.image = [UIImage imageNamed:image_lock];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // downloadFile
    // ----------------------------------------------------------------------------------------------------------
    
    if ([metadata.session length] > 0 && [metadata.session rangeOfString:@"download"].location != NSNotFound) {
        
        if (metadata.cryptated) cell.statusImageView.image = [UIImage imageNamed:image_statusdownloadcrypto];
        else cell.statusImageView.image = [UIImage imageNamed:image_statusdownload];
        
        // Fai comparire il RELOAD e lo STOP solo se non è un Task Plist
        if (metadata.sessionTaskIdentifierPlist == taskIdentifierDone) {
            
            if (metadata.cryptated)[cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptaskcrypto] forState:UIControlStateNormal];
            else [cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptask] forState:UIControlStateNormal];
            
            cell.cancelTaskButton.hidden = NO;
            
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


@end

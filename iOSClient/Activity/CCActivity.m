//
//  CCActivity.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 12/04/17.
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

#import "CCActivity.h"
#import "AppDelegate.h"
#import "CCSection.h"
#import "NCBridgeSwift.h"

#define fontSizeData    [UIFont boldSystemFontOfSize:15]
#define fontSizeAction  [UIFont systemFontOfSize:14]
#define fontSizeNote    [UIFont systemFontOfSize:14]

@interface CCActivity ()
{
    BOOL _verbose;

    // Datasource
    NSArray *_sectionDataSource;
}
@end

@implementation CCActivity

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        app.activeActivity = self;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.collectionView.emptyDataSetSource = self;
    self.collectionView.emptyDataSetDelegate = self;
    self.collectionView.delegate = self;
    
    _verbose = [CCUtility getActivityVerboseHigh];
    
    _sectionDataSource = [NSArray new];
    
    self.title = NSLocalizedString(@"_activity_", nil);

    [self reloadDatasource];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _verbose = [CCUtility getActivityVerboseHigh];
    
    // Color
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [app aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Plus Button
    [app plusButtonVisibile:true];
}

// E' arrivato
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self reloadDatasource];
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [app changeTheming:self];
}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)emptyDataSetShouldDisplay:(UIScrollView *)scrollView
{
    if([_sectionDataSource count] > 0)
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
    return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"activityNoRecord"] color:[NCBrandColor sharedInstance].brand];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_no_activity_", nil)];

    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasource
{
    // test
    if (app.activeAccount.length == 0)
        return;
    
    NSPredicate *predicate;
        
    NSDate *sixDaysAgo = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitDay value:-k_daysOfActivity toDate:[NSDate date] options:0];
        
    if (_verbose)
        predicate = [NSPredicate predicateWithFormat:@"account = %@ AND date > %@", app.activeAccount, sixDaysAgo];
    else
        predicate = [NSPredicate predicateWithFormat:@"account = %@ AND verbose = %lu AND date > %@", app.activeAccount, k_activityVerboseDefault, sixDaysAgo];

    _sectionDataSource = [[NCManageDatabase sharedInstance] getActivityWithPredicate:predicate];
        
    [self reloadCollection];
}

- (void)reloadCollection
{
    NSDate *dateActivity;
    
    if ([_sectionDataSource count] > 0)
        dateActivity = ((tableActivity *)[_sectionDataSource objectAtIndex:0]).date;

    if ([dateActivity compare:_storeDateFirstActivity] == NSOrderedDescending || _storeDateFirstActivity == nil || dateActivity == nil) {
        _storeDateFirstActivity = dateActivity;
        [self.collectionView reloadData];
    }    
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [_sectionDataSource count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    tableActivity *activity = [_sectionDataSource objectAtIndex:section];
    
    if (activity.fileID.length > 0) {
     
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", activity.fileID]];
        
        if (metadata && ([activity.action isEqual: k_activityDebugActionDownload] || [activity.action isEqual: k_activityDebugActionUpload])) {
            
            /*
            if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, activity.fileID]]) {
                return 1;
            } else {
                return 0;
            }
            */
            
            return 1;
        }
    }
    
    return 0;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    tableActivity *activity = [_sectionDataSource objectAtIndex:section];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, collectionView.frame.size.width - 40, CGFLOAT_MAX)];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    [label sizeToFit];
    
    // Action
    [label setFont:fontSizeAction];
    label.text = [NSString stringWithFormat:@"%@ %@", activity.action, activity.file];
    int heightAction = [[self class] getLabelHeight:label width:self.collectionView.frame.size.width];
    
    // Note
    [label setFont:fontSizeNote];
    
    if (_verbose && activity.idActivity == 0 && [activity.selector length] > 0)
        label.text = [NSString stringWithFormat:@"%@ Selector: %@", activity.note, activity.selector];
    else
        label.text = activity.note;
    
    int heightNote = [[self class] getLabelHeight:label width:self.collectionView.frame.size.width];
    
    int heightView = 40 + heightAction + heightNote + 17;
    
    return CGSizeMake(collectionView.frame.size.width, heightView);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionReusableView *reusableview;
    
    if (kind == UICollectionElementKindSectionHeader) {
    
        reusableview = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
        
        tableActivity *activity = [_sectionDataSource objectAtIndex:indexPath.section];
    
        UILabel *dateLabel = (UILabel *)[reusableview viewWithTag:100];
        UILabel *actionLabel = (UILabel *)[reusableview viewWithTag:101];
        UILabel *noteLabel = (UILabel *)[reusableview viewWithTag:102];
        UIImageView *typeImage = (UIImageView *) [reusableview viewWithTag:103];
    
        [dateLabel setFont:fontSizeData];
        dateLabel.textColor = [UIColor colorWithRed:100.0/255.0 green:100.0/255.0 blue:100.0/255.0 alpha:1.0];
    
        if (_verbose) {
        
            dateLabel.text = [NSDateFormatter localizedStringFromDate:activity.date dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterMediumStyle];
        
        } else {
        
            NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:activity.date];
            dateLabel.text = [CCUtility getTitleSectionDate:[[NSCalendar currentCalendar] dateFromComponents:comps]];
        }
    
        [actionLabel setFont:fontSizeAction];
        [actionLabel sizeToFit];
        actionLabel.text = [NSString stringWithFormat:@"%@ %@", activity.action, activity.file];

        if ([activity.type isEqualToString:k_activityTypeInfo]) {
        
            actionLabel.textColor = [NCBrandColor sharedInstance].brand;
        
            if (activity.idActivity == 0)
                typeImage.image = [UIImage imageNamed:@"activityTypeInfo"];
            else
                typeImage.image = [UIImage imageNamed:@"activityTypeInfoServer"];
        }
    
        if ([activity.type isEqualToString:k_activityTypeSuccess]) {
        
            actionLabel.textColor = [UIColor colorWithRed:87.0/255.0 green:187.0/255.0 blue:57.0/255.0 alpha:1.0];;
            typeImage.image = [UIImage imageNamed:@"activityTypeSuccess"];
        }
    
        if ([activity.type isEqualToString:k_activityTypeFailure]) {
        
            actionLabel.textColor = [UIColor redColor];
            typeImage.image = [UIImage imageNamed:@"activityTypeFailure"];
        }
    
        [noteLabel setFont:fontSizeNote];
        [noteLabel sizeToFit];
        noteLabel.textColor = [UIColor blackColor];
        noteLabel.numberOfLines = 0;
        noteLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
        if (_verbose && activity.idActivity == 0 && [activity.selector length] > 0)
            noteLabel.text = [NSString stringWithFormat:@"%@ Selector: %@", activity.note, activity.selector];
        else
            noteLabel.text = activity.note;
    }
    
    if (kind == UICollectionElementKindSectionFooter) {
        
         reusableview = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footer" forIndexPath:indexPath];
    }
    
    return reusableview;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    //cell.backgroundColor = [UIColor clearColor];
    UIImageView *imageView = (UIImageView *)[cell viewWithTag:104];

    tableActivity *activity = [_sectionDataSource objectAtIndex:indexPath.section];
    
    if (activity.fileID.length > 0) {
        
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", activity.fileID]];
        
        if (metadata && ([activity.action isEqual: k_activityDebugActionDownload] || [activity.action isEqual: k_activityDebugActionUpload])) {
            
             if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, activity.fileID]]) {
             
                 imageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, activity.fileID]];
                 
             } else {
                 
                 imageView.image = [UIImage imageNamed:metadata.iconName];
             }
        }
    } else {
        
        imageView.image = [UIImage imageNamed:@"file"];
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    tableActivity *activity = [_sectionDataSource objectAtIndex:indexPath.section];
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", activity.fileID]];
    
    BOOL existsFile = [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", app.directoryUser, activity.fileID]];
    
    if (metadata && existsFile) {
        
        if (!self.splitViewController.isCollapsed && app.activeMain.detailViewController.isViewLoaded && app.activeMain.detailViewController.view.window)
            [app.activeMain.navigationController popToRootViewControllerAnimated:NO];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            [app.activeMain performSegueWithIdentifier:@"segueDetail" sender:metadata];            
        });
        
    } else {
        
        [app messageNotification:@"_info_" description:@"_activity_file_not_present_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Utility ====
#pragma --------------------------------------------------------------------------------------------

+ (CGFloat)getLabelHeight:(UILabel*)label width:(int)width
{
    CGSize constraint = CGSizeMake(width, CGFLOAT_MAX);
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attributes = @{NSFontAttributeName : label.font, NSParagraphStyleAttributeName: paragraph};
    
    NSStringDrawingContext *context = [NSStringDrawingContext new];
    CGSize boundingBox = [label.text boundingRectWithSize:constraint options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:context].size;
    
    CGSize size = CGSizeMake(ceil(boundingBox.width), ceil(boundingBox.height));
    
    return size.height;
}

@end

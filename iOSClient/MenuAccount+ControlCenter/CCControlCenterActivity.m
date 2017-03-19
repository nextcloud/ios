//
//  CCControlCenterActivity.m
//  Nextcloud
//
//  Created by Marino Faggiana on 01/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "CCControlCenterActivity.h"

#import "AppDelegate.h"
#import "CCSection.h"

#define fontSizeData    [UIFont boldSystemFontOfSize:15]
#define fontSizeAction  [UIFont systemFontOfSize:14]
#define fontSizeNote    [UIFont systemFontOfSize:14]

@interface CCControlCenterActivity ()
{
    // Datasource
    NSArray *_sectionDataSource;
}
@end

@implementation CCControlCenterActivity

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        app.controlCenterActivity = self;
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    _sectionDataSource = [NSArray new];
    
    [self reloadDatasource];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    app.controlCenter.labelMessageNoRecord.hidden = YES;
}

// E' arrivato
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self reloadDatasource];
}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasource
{
    // test
    if (app.activeAccount.length == 0)
        return;
    
    if (app.controlCenter.isOpen) {
        
         //_sectionDataSource = [CCCoreData getAllTableActivityWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (idActivity != 0)", app.activeAccount]];
        
        if ([CCUtility getActivityVerboseDebug])
            _sectionDataSource = [CCCoreData getAllTableActivityWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", app.activeAccount]];
        else
            _sectionDataSource = [CCCoreData getAllTableActivityWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (verbose == %lu)", app.activeAccount, k_activityVerboseDefault]];
        
        if ([[app.controlCenter getActivePage] isEqualToString:k_pageControlCenterActivity]) {
            
            if ([_sectionDataSource count] == 0) {
                
                app.controlCenter.labelMessageNoRecord.text = NSLocalizedString(@"_no_activity_",nil);
                app.controlCenter.labelMessageNoRecord.hidden = NO;
            
            } else {
            
                app.controlCenter.labelMessageNoRecord.hidden = YES;
            }
        }
    }
    
    [self.collectionView reloadData];    
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
    /*
    TableActivity *activity = [_sectionDataSource objectAtIndex:section];
    
    if ([activity.file length] > 0)
        return 1;
    else
        return 0;
    */
    
    return 0;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    TableActivity *activity = [_sectionDataSource objectAtIndex:section];
    
    UILabel *noteLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, collectionView.frame.size.width , CGFLOAT_MAX)];
    noteLabel.numberOfLines = 0;
    [noteLabel setFont:fontSizeNote];
    noteLabel.text = activity.note;
    noteLabel.lineBreakMode = NSLineBreakByWordWrapping;
    int heighNoteLabel = [self getLabelHeight:noteLabel];

    int heightView = 90 + heighNoteLabel + (heighNoteLabel/5);
    
    if (heightView < 90)
        heightView = 90;
    
    return CGSizeMake(collectionView.frame.size.width, heightView);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
        
    TableActivity *activity = [_sectionDataSource objectAtIndex:indexPath.section];
    
    UILabel *dateLabel = (UILabel *)[headerView viewWithTag:100];
    UILabel *actionLabel = (UILabel *)[headerView viewWithTag:101];
    UILabel *noteLabel = (UILabel *)[headerView viewWithTag:102];
    UIImageView *typeImage = (UIImageView *) [headerView viewWithTag:103];
    
    [dateLabel setFont:fontSizeData];
    dateLabel.textColor = [UIColor colorWithRed:100.0/255.0 green:100.0/255.0 blue:100.0/255.0 alpha:1.0];
    
    if ([CCUtility getActivityVerboseDebug]) {
        
        dateLabel.text = [NSDateFormatter localizedStringFromDate:activity.date dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterMediumStyle];
        
    } else {
        
        NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:activity.date];
        dateLabel.text = [CCUtility getTitleSectionDate:[[NSCalendar currentCalendar] dateFromComponents:comps]];
    }
    
    [actionLabel setFont:fontSizeAction];
    actionLabel.text = [NSString stringWithFormat:@"%@ %@", activity.action, activity.file];

    if ([activity.type isEqualToString:k_activityTypeInfo]) {
        
        actionLabel.textColor = COLOR_BRAND;
        
        if ([activity.verbose integerValue] == k_activityVerboseDebug)
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
    noteLabel.textColor = COLOR_TEXT_ANTHRACITE;
    noteLabel.numberOfLines = 0;
    noteLabel.lineBreakMode = NSLineBreakByWordWrapping;
    noteLabel.text = activity.note;
    
    //headerView.backgroundColor = [UIColor blueColor];
        
    return headerView;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    
    TableActivity *activity = [_sectionDataSource objectAtIndex:indexPath.section];
    
    NSString *dir = [activity.file stringByDeletingLastPathComponent];
    NSString *fileName = [activity.file lastPathComponent];
    
    if ([dir length] > 0 && [fileName length] > 0) {
        
    }
    
    return cell;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Utility ====
#pragma --------------------------------------------------------------------------------------------

- (CGFloat)getLabelHeight:(UILabel*)label
{
    CGSize constraint = CGSizeMake(self.collectionView.frame.size.width, CGFLOAT_MAX);
    
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attributes = @{NSFontAttributeName : label.font, NSParagraphStyleAttributeName: paragraph};
    
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    CGSize boundingBox = [label.text boundingRectWithSize:constraint options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:context].size;
    
    CGSize size = CGSizeMake(ceil(boundingBox.width), ceil(boundingBox.height));
    
    return size.height;
}

@end

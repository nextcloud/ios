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
                
        if ([CCUtility getActivityVerboseHigh])
            _sectionDataSource = [CCCoreData getAllTableActivityWithPredicate:[NSPredicate predicateWithFormat:@"((account == %@) || (account == ''))", app.activeAccount]];
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
    TableActivity *activity = [_sectionDataSource objectAtIndex:section];
    
    if ([activity.action isEqual: k_activityDebugActionDownload] || [activity.action isEqual: k_activityDebugActionUpload]) {
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, activity.fileID]])
            return 1;
        else
            return 0;
    }
    
    return 0;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    TableActivity *activity = [_sectionDataSource objectAtIndex:section];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, collectionView.frame.size.width - 40, CGFLOAT_MAX)];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    [label sizeToFit];
    
    // Action
    [label setFont:fontSizeAction];
    label.text = [NSString stringWithFormat:@"%@ %@", activity.action, activity.file];
    int heightAction = [self getLabelHeight:label];
    
    // Note
    [label setFont:fontSizeNote];
    if ([CCUtility getActivityVerboseHigh] && activity.idActivity == 0) label.text = [NSString stringWithFormat:@"%@ Selector: %@", activity.note, activity.selector];
    else label.text = activity.note;
    int heightNote = [self getLabelHeight:label];

    int heightView = 40 + heightAction + heightNote;
    
    return CGSizeMake(collectionView.frame.size.width, heightView);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (kind == UICollectionElementKindSectionHeader) {
    
        UICollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
        
        TableActivity *activity = [_sectionDataSource objectAtIndex:indexPath.section];
    
        UILabel *dateLabel = (UILabel *)[headerView viewWithTag:100];
        UILabel *actionLabel = (UILabel *)[headerView viewWithTag:101];
        UILabel *noteLabel = (UILabel *)[headerView viewWithTag:102];
        UIImageView *typeImage = (UIImageView *) [headerView viewWithTag:103];
    
        [dateLabel setFont:fontSizeData];
        dateLabel.textColor = [UIColor colorWithRed:100.0/255.0 green:100.0/255.0 blue:100.0/255.0 alpha:1.0];
    
        if ([CCUtility getActivityVerboseHigh]) {
        
            dateLabel.text = [NSDateFormatter localizedStringFromDate:activity.date dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterMediumStyle];
        
        } else {
        
            NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:activity.date];
            dateLabel.text = [CCUtility getTitleSectionDate:[[NSCalendar currentCalendar] dateFromComponents:comps]];
        }
    
        [actionLabel setFont:fontSizeAction];
        [actionLabel sizeToFit];
        actionLabel.text = [NSString stringWithFormat:@"%@ %@", activity.action, activity.file];

        if ([activity.type isEqualToString:k_activityTypeInfo]) {
        
            actionLabel.textColor = COLOR_BRAND;
        
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
        noteLabel.textColor = COLOR_TEXT_ANTHRACITE;
        noteLabel.numberOfLines = 0;
        noteLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
        if ([CCUtility getActivityVerboseHigh] && activity.idActivity == 0) noteLabel.text = [NSString stringWithFormat:@"%@ Selector: %@", activity.note, activity.selector];
        else noteLabel.text = activity.note;
        
        return headerView;
    }
    
    if (kind == UICollectionElementKindSectionFooter) {
        
        UICollectionReusableView *footerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footer" forIndexPath:indexPath];
        
        return footerView;
    }
    
    return nil;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    UIImageView *imageView = (UIImageView *)[cell viewWithTag:104];

    TableActivity *activity = [_sectionDataSource objectAtIndex:indexPath.section];
    
    imageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, activity.fileID]];
    
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

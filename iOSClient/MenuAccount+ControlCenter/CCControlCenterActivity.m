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

@interface CCControlCenterActivity ()
{
    // Datasource
    NSArray *_sectionDataSource;
    NSDate *_oldDate;
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
    _oldDate = [NSDate date];
    
    // empty Data Source
  
    /*
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];
    */
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self reloadDatasource];
}

// E' arrivato
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
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
        
         _sectionDataSource = [CCCoreData getAllTableActivityWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", app.activeAccount]];
        
        //_sectionDataSource = [CCSectionActivity creataDataSourseSectionActivity:records activeAccount:app.activeAccount];
        
        if ([_sectionDataSource count] == 0) {
            
            app.controlCenter.noRecord.text = NSLocalizedString(@"_no_activity_",nil);
            app.controlCenter.noRecord.hidden = NO;
            
        } else {
            
            app.controlCenter.noRecord.hidden = YES;
        }
    }
    
    [self.collectionView reloadData];
    
    [app updateApplicationIconBadgeNumber];
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
    //return [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:section]] count];
    return 10;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    TableActivity *activity = [_sectionDataSource objectAtIndex:section];
    
    UILabel *subjectLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, collectionView.frame.size.width , CGFLOAT_MAX)];
    subjectLabel.numberOfLines = 0;
    subjectLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [subjectLabel setFont:[UIFont fontWithName:@"System" size:12]];
    subjectLabel.text = activity.subject;
    [subjectLabel sizeToFit];

    return CGSizeMake(collectionView.frame.size.width, subjectLabel.frame.size.height+22+20);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (kind == UICollectionElementKindSectionHeader) {
        
        UICollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
        
        TableActivity *activity = [_sectionDataSource objectAtIndex:indexPath.section];
        
        NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:activity.date];
        NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:comps];
        
        UILabel *dataLabel = (UILabel *)[headerView viewWithTag:100];
        UILabel *subjectLabel = (UILabel *)[headerView viewWithTag:101];
        
        dataLabel.textColor = COLOR_TEXT_ANTHRACITE;
        dataLabel.text =  [CCUtility getTitleSectionDate:date];
        
        subjectLabel.textColor = COLOR_TEXT_ANTHRACITE;
        subjectLabel.text = activity.subject;
        
        
        CGFloat x = [self getLabelHeight:subjectLabel];
        
        headerView.frame = CGRectMake(headerView.frame.origin.x, headerView.frame.origin.y, headerView.frame.size.width, 20 + dataLabel.frame.size.height + x);
        headerView.backgroundColor = [UIColor redColor];

        return headerView;
    }
    
    return nil;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    
    //NSArray *metadatasForKey = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]];
    //TableActivity *activity = [metadatasForKey objectAtIndex:indexPath.row];

    
    return cell;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Utility ====
#pragma --------------------------------------------------------------------------------------------


- (CGFloat)getLabelHeight:(UILabel*)label
{
    CGSize constraint = CGSizeMake(label.frame.size.width, CGFLOAT_MAX);
    CGSize size;
    
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    CGSize boundingBox = [label.text boundingRectWithSize:constraint options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:label.font} context:context].size;
    
    size = CGSizeMake(ceil(boundingBox.width), ceil(boundingBox.height));
    
    return size.height;
}

@end

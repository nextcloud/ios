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

#define fontSizeData    [UIFont systemFontOfSize:16]
#define fontSizeSubject [UIFont systemFontOfSize:14]

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
        
         _sectionDataSource = [CCCoreData getAllTableActivityWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", app.activeAccount]];
        
        //_sectionDataSource = [CCSectionActivity creataDataSourseSectionActivity:records activeAccount:app.activeAccount];
        
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
    return 0;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    TableActivity *activity = [_sectionDataSource objectAtIndex:section];
    
    UILabel *subjectLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, collectionView.frame.size.width , CGFLOAT_MAX)];
    subjectLabel.numberOfLines = 0;
    subjectLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [subjectLabel setFont:fontSizeSubject];
    subjectLabel.text = activity.subject;
    [subjectLabel sizeToFit];

    int heightView = 50 + subjectLabel.frame.size.height;
    if (heightView < 60)
        heightView = 60;
    
    return CGSizeMake(collectionView.frame.size.width, heightView);
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
        UIImageView *typeImage = (UIImageView *) [headerView viewWithTag:102];
        
        dataLabel.textColor = [UIColor colorWithRed:130.0/255.0 green:130.0/255.0 blue:130.0/255.0 alpha:1.0];
        dataLabel.text =  [CCUtility getTitleSectionDate:date];
        [dataLabel setFont:fontSizeData];
        
        if ([activity.type length] == 0 )
            typeImage.image = [UIImage imageNamed:image_user];
        
        subjectLabel.textColor = COLOR_TEXT_ANTHRACITE;
        subjectLabel.text = activity.subject;
        [subjectLabel setFont:fontSizeSubject];
        
        int heightView = 50 + [self getLabelHeight:subjectLabel];
        
        if (heightView < 60)
            heightView = 60;
        
        headerView.frame = CGRectMake(headerView.frame.origin.x, headerView.frame.origin.y,  headerView.frame.size.width, heightView);
        //headerView.backgroundColor = [UIColor greenColor];
        
        return headerView;
    }
    
    return nil;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    
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

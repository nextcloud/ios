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
    CCSectionDataSourceActivity *_sectionDataSource;
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
    
    _sectionDataSource = [CCSectionDataSourceActivity new];
    
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
        
        NSArray *records = [CCCoreData getAllTableActivityWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@)", app.activeAccount]];
        
        _sectionDataSource = [CCSectionActivity creataDataSourseSectionActivity:records activeAccount:app.activeAccount];
        
        if ([records count] == 0) {
            
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
    return [[_sectionDataSource.sectionArrayRow allKeys] count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:section]] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];

    NSArray *metadatasForKey = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]];
    TableActivity *activity = [metadatasForKey objectAtIndex:indexPath.row];

    
    return cell;
}

@end

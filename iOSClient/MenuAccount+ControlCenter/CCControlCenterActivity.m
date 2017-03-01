//
//  CCControlCenterActivity.m
//  Nextcloud
//
//  Created by Marino Faggiana on 01/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "CCControlCenterActivity.h"

#import "CCControlCenterTransferCell.h"

@implementation CCControlCenterActivity

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    // Custom Cell
    [_tableView registerNib:[UINib nibWithNibName:@"CCControlCenterTransferCell" bundle:nil] forCellReuseIdentifier:@"ControlCenterTransferCell"];
    
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor greenColor];
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
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 13.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CCControlCenterTransferCell *cell = (CCControlCenterTransferCell *)[tableView dequeueReusableCellWithIdentifier:@"ControlCenterTransferCell" forIndexPath:indexPath];
    
    return cell;
}

@end

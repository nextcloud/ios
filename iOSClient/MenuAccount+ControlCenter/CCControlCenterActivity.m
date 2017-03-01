//
//  CCControlCenterActivity.m
//  Nextcloud
//
//  Created by Marino Faggiana on 01/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "CCControlCenterActivity.h"

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

@end

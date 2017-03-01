//
//  CCControlCenterActivity.h
//  Nextcloud
//
//  Created by Marino Faggiana on 01/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CCControlCenterActivity : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property NSUInteger pageIndex;
@property (nonatomic, strong) NSString *pageType;

@property (nonatomic, weak) IBOutlet UITableView *tableView;

@end

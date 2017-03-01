//
//  CCControlCenterTransfer.h
//  Nextcloud
//
//  Created by Marino Faggiana on 01/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CCControlCenterTransfer : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property NSUInteger pageIndex;
@property (nonatomic, strong) NSString *pageType;

@property (nonatomic, weak) IBOutlet UITableView *tableView;

- (void)reloadDatasource;
- (void)progressTask:(NSString *)fileID serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated progress:(float)progress;

@end

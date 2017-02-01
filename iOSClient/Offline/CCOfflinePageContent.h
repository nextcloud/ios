//
//  CCOfflinePageContent.h
//  Nextcloud
//
//  Created by Marino Faggiana on 01/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CCDetail.h"

@interface CCOfflinePageContent : UITableViewController

@property NSUInteger pageIndex;
@property (nonatomic, strong) NSString *pageType;


@property (nonatomic, weak) CCDetail *detailViewController;
@property (nonatomic, strong) UIDocumentInteractionController *docController;

@end

//
//  CCShareDB.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 23/11/15.
//  Copyright (c) 2014 TWS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XLFormViewController.h"

#import "CCMetadata.h"

@protocol CCShareDBDelegate;

@interface CCShareDB : XLFormViewController

@property (nonatomic, weak) id <CCShareDBDelegate> delegate;

@property (nonatomic, weak) IBOutlet UIImageView *fileImageView;
@property (nonatomic, weak) IBOutlet UILabel *labelTitle;
@property (nonatomic, weak) IBOutlet UIButton *endButton;

@property (nonatomic, strong) CCMetadata *metadata;
@property (nonatomic, strong) NSString *serverUrl;
@property (nonatomic, strong) NSString *shareLink;

- (void)reloadData;

- (IBAction)endButtonAction:(id)sender;

@end


@protocol CCShareDBDelegate

- (void)share:(CCMetadata *)metadata serverUrl:(NSString *)serverUrl password:(NSString *)password;
- (void)unShare:(NSString *)share metadata:(CCMetadata *)metadata serverUrl:(NSString *)serverUrl;
- (void)getDataSourceWithReloadTableView:(NSString *)directoryID fileID:(NSString *)fileID selector:(NSString *)selector;

@end

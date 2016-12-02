//
//  DBConnectController.h
//  DropboxSDK
//
//  Created by Brian Smith on 5/4/12.
//  Copyright (c) 2012 Dropbox, Inc. All rights reserved.
//

#import "DBSession.h"

@interface DBConnectController : UIViewController

- (id)initWithUrl:(NSURL *)connectUrl fromController:(UIViewController *)rootController;
- (id)initWithUrl:(NSURL *)connectUrl fromController:(UIViewController *)rootController session:(DBSession *)session;

@end

//
//  OCNotificationsAction.h
//  ownCloud iOS library
//
//  Created by Marino Faggiana on 23/01/17.
//  Copyright © 2017 ownCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OCNotificationsAction : NSObject

@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) NSString *link;
@property (nonatomic, strong) NSString *type;
@property BOOL primary;

@end

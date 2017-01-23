//
//  OCNotifications.h
//  ownCloud iOS library
//
//  Created by Marino Faggiana on 23/01/17.
//  Copyright © 2017 ownCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OCNotifications : NSObject

@property NSInteger idNotification;
@property (nonatomic, strong) NSString *app;
@property (nonatomic, strong) NSString *user;
@property long date;
@property (nonatomic, strong) NSString *typeObject;
@property (nonatomic, strong) NSString *idObject;
@property (nonatomic, strong) NSString *subject;
@property (nonatomic, strong) NSString *subjectRich;
@property (nonatomic, strong) NSArray *subjectRichParameters;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, strong) NSString *messageRich;
@property (nonatomic, strong) NSArray *messageRichParameters;
@property (nonatomic, strong) NSString *link;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) NSArray *action;

@end


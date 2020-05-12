//
//  BKTouchIDManager.h
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 10. 12..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BKTouchIDManager : NSObject

@property (nonatomic, strong, readonly) NSString                *keychainServiceName;
@property (nonatomic, strong) NSString                          *promptText;
@property (nonatomic, readonly, getter=isTouchIDEnabled) BOOL   touchIDEnabled;

+ (BOOL)canUseTouchID;

- (instancetype)initWithKeychainServiceName:(NSString *)serviceName;

- (void)savePasscode:(NSString *)passcode completionBlock:(void(^)(BOOL success))completionBlock;

- (void)loadPasscodeWithCompletionBlock:(void(^)(NSString *passcode))completionBlock;

- (void)deletePasscodeWithCompletionBlock:(void(^)(BOOL success))completionBlock;

@end

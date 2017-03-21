//
//  BKTouchIDManager.m
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 10. 12..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//

#import "BKTouchIDManager.h"
#import <LocalAuthentication/LocalAuthentication.h>

static NSString *const BKTouchIDManagerPasscodeAccountName = @"passcode";
static NSString *const BKTouchIDManagerTouchIDEnabledAccountName = @"enabled";

@interface BKTouchIDManager () {
    dispatch_queue_t _queue;
}

@property (nonatomic, strong) NSString                  *keychainServiceName;

@end

@implementation BKTouchIDManager

- (instancetype)initWithKeychainServiceName:(NSString *)serviceName
{
    self = [super init];
    if (self) {
        
        _queue = dispatch_queue_create("BKTouchIDManagerQueue", DISPATCH_QUEUE_SERIAL);
        
        NSParameterAssert(serviceName);
        
        self.keychainServiceName = serviceName;
    }
    return self;
}

+ (BOOL)canUseTouchID
{
    if (![LAContext class]) {
        return NO;
    }
    
    LAContext *context = [[LAContext alloc] init];
    
    NSError *error = nil;
    BOOL result = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
    
    return result;
}

- (void)savePasscode:(NSString *)passcode completionBlock:(void(^)(BOOL success))completionBlock
{
    NSParameterAssert(passcode);
    
    if (NO == [[self class] canUseTouchID]) {
        if (completionBlock) {
            completionBlock(NO);
        }
        return;
    }
    
    NSString *serviceName = self.keychainServiceName;
    NSData *passcodeData = [passcode dataUsingEncoding:NSUTF8StringEncoding];
    
    dispatch_async(_queue, ^{
        
        BOOL success = [[self class] saveKeychainItemWithServiceName:serviceName
                                                         accountName:BKTouchIDManagerPasscodeAccountName
                                                                data:passcodeData
                                                            sacFlags:kSecAccessControlUserPresence];
        
        if (success) {
            
            BOOL enabled = YES;
            
            success = [[self class] saveKeychainItemWithServiceName:serviceName
                                                        accountName:BKTouchIDManagerTouchIDEnabledAccountName
                                                               data:[NSData dataWithBytes:&enabled length:sizeof(BOOL)]
                                                           sacFlags:0];
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(success);
            });
        }
    });
}

- (void)loadPasscodeWithCompletionBlock:(void (^)(NSString *))completionBlock
{
    if (NO == [[self class] canUseTouchID]) {
        if (completionBlock) {
            completionBlock(nil);
        }
        return;
    }
    
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithDictionary:@{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                                                                  (__bridge id)kSecAttrService: self.keychainServiceName,
                                                                                  (__bridge id)kSecAttrAccount: BKTouchIDManagerPasscodeAccountName,
                                                                                  (__bridge id)kSecReturnData: @YES }];
    
    if (self.promptText) {
        query[(__bridge id)kSecUseOperationPrompt] = self.promptText;
    }
    
    dispatch_async(_queue, ^{
    
        CFTypeRef dataTypeRef = NULL;
        
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)(query), &dataTypeRef);
        
        NSString *result = nil;
        
        if (status == errSecSuccess) {
            
            NSData *resultData = ( __bridge_transfer NSData *)dataTypeRef;
            result = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(result);
            });
        }
    });
}

- (void)deletePasscodeWithCompletionBlock:(void (^)(BOOL))completionBlock
{
    dispatch_async(_queue, ^{
        
        BOOL success = ([[self class] deleteKeychainItemWithServiceName:self.keychainServiceName accountName:BKTouchIDManagerPasscodeAccountName] &&
                        [[self class] deleteKeychainItemWithServiceName:self.keychainServiceName accountName:BKTouchIDManagerTouchIDEnabledAccountName]);
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(success);
            });
        }
    });
}

- (BOOL)isTouchIDEnabled
{
    NSDictionary *query = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                             (__bridge id)kSecAttrService: self.keychainServiceName,
                             (__bridge id)kSecAttrAccount: BKTouchIDManagerTouchIDEnabledAccountName,
                             (__bridge id)kSecReturnData: @YES };
    
    CFTypeRef dataTypeRef = NULL;
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)(query), &dataTypeRef);
    
    if (status == errSecSuccess) {
        
        NSData *resultData = ( __bridge_transfer NSData *)dataTypeRef;
        BOOL result;
        [resultData getBytes:&result length:sizeof(BOOL)];
        
        return result;
        
    } else {
        return NO;
    }
}

#pragma mark - Static Methods

+ (BOOL)saveKeychainItemWithServiceName:(NSString *)serviceName accountName:(NSString *)accountName data:(NSData *)data sacFlags:(SecAccessControlCreateFlags)sacFlags
{
    // try to update first
    BOOL success = [self updateKeychainItemWithServiceName:serviceName accountName:accountName data:data];
    
    if (success) {
        return YES;
    }
    
    // try deleting when update failed (workaround for iOS 8 bug)
    [self deleteKeychainItemWithServiceName:serviceName accountName:accountName];
    
    // try add
    return [self addKeychainItemWithServiceName:serviceName accountName:accountName data:data sacFlags:sacFlags];
}

+ (BOOL)addKeychainItemWithServiceName:(NSString *)serviceName accountName:(NSString *)accountName data:(NSData *)data sacFlags:(SecAccessControlCreateFlags)sacFlags
{
    CFErrorRef error = NULL;
    SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                                    sacFlags, &error);
    
    if (sacObject == NULL || error != NULL) {
        return NO;
    }
    
    NSDictionary *attributes = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                  (__bridge id)kSecAttrService: serviceName,
                                  (__bridge id)kSecAttrAccount: accountName,
                                  (__bridge id)kSecValueData: data,
                                  (__bridge id)kSecUseNoAuthenticationUI: @YES,
                                  (__bridge id)kSecAttrAccessControl: (__bridge_transfer id)sacObject };
    
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)attributes, nil);
    
    return (status == errSecSuccess);
}

+ (BOOL)updateKeychainItemWithServiceName:(NSString *)serviceName accountName:(NSString *)accountName data:(NSData *)data
{
    NSDictionary *query = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                             (__bridge id)kSecAttrService: serviceName,
                             (__bridge id)kSecAttrAccount: accountName };
    
    NSDictionary *changes = @{ (__bridge id)kSecValueData: data };
    
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)changes);
    
    return (status == errSecSuccess);
}

+ (BOOL)deleteKeychainItemWithServiceName:(NSString *)serviceName accountName:(NSString *)accountName
{
    NSDictionary *query = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                             (__bridge id)kSecAttrService: serviceName,
                             (__bridge id)kSecAttrAccount: accountName };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)(query));

    return (status == errSecSuccess || status == errSecItemNotFound);
}

@end

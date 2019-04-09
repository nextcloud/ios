//
//  KTVHCDataUnitItem.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataUnitItem.h"
#import "KTVHCPathTool.h"
#import "KTVHCLog.h"

@interface KTVHCDataUnitItem ()

@property (nonatomic, strong) NSRecursiveLock *coreLock;

@end

@implementation KTVHCDataUnitItem

- (id)copyWithZone:(NSZone *)zone
{
    [self lock];
    KTVHCDataUnitItem *obj = [[KTVHCDataUnitItem alloc] init];
    obj->_relativePath = self.relativePath;
    obj->_absolutePath = self.absolutePath;
    obj->_createTimeInterval = self.createTimeInterval;
    obj->_offset = self.offset;
    obj->_length = self.length;
    [self unlock];
    return obj;
}

- (instancetype)initWithPath:(NSString *)path
{
    return [self initWithPath:path offset:0];
}

- (instancetype)initWithPath:(NSString *)path offset:(uint64_t)offset
{
    if (self = [super init]) {
        self->_createTimeInterval = [NSDate date].timeIntervalSince1970;
        self->_relativePath = [KTVHCPathTool converToRelativePath:path];
        self->_absolutePath = [KTVHCPathTool converToAbsoultePath:path];
        self->_offset = offset;
        self->_length = [KTVHCPathTool sizeAtPath:self.absolutePath];
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        self->_createTimeInterval = [[aDecoder decodeObjectForKey:@"createTimeInterval"] doubleValue];
        self->_relativePath = [aDecoder decodeObjectForKey:@"relativePath"];
        self->_absolutePath = [KTVHCPathTool converToAbsoultePath:self.relativePath];
        self->_offset = [[aDecoder decodeObjectForKey:@"offset"] longLongValue];
        self->_length = [KTVHCPathTool sizeAtPath:self.absolutePath];
        [self commonInit];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(self.createTimeInterval) forKey:@"createTimeInterval"];
    [aCoder encodeObject:self.relativePath forKey:@"relativePath"];
    [aCoder encodeObject:@(self.offset) forKey:@"offset"];
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (void)commonInit
{
    KTVHCLogAlloc(self);
    KTVHCLogDataUnitItem(@"%p, Create Unit Item\nabsolutePath : %@\nrelativePath : %@\nOffset : %lld\nLength : %lld", self, self.absolutePath, self.relativePath, self.offset, self.length);
}

- (void)updateLength:(long long)length
{
    [self lock];
    self->_length = length;
    KTVHCLogDataUnitItem(@"%p, Set length : %lld", self, length);
    [self unlock];
}

- (void)lock
{
    if (!self.coreLock) {
        self.coreLock = [[NSRecursiveLock alloc] init];
    }
    [self.coreLock lock];
}

- (void)unlock
{
    [self.coreLock unlock];
}

@end

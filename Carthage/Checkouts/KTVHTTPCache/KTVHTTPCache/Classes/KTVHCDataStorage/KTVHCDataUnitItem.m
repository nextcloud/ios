//
//  KTVHCDataUnitItem.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataUnitItem.h"
#import "KTVHCPathTools.h"
#import "KTVHCLog.h"

@interface KTVHCDataUnitItem ()

@property (nonatomic, strong) NSRecursiveLock * coreLock;

@end

@implementation KTVHCDataUnitItem

- (id)copyWithZone:(NSZone *)zone
{
    [self lock];
    KTVHCDataUnitItem * obj = [[KTVHCDataUnitItem alloc] initForCopy];
    obj->_relativePath = self.relativePath;
    obj->_absolutePath = self.absolutePath;
    obj->_createTimeInterval = self.createTimeInterval;
    obj->_offset = self.offset;
    obj->_length = self.length;
    [self unlock];
    return obj;
}

- (instancetype)initForCopy
{
    if (self = [super init])
    {
        
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path offset:(long long)offset
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        _createTimeInterval = [NSDate date].timeIntervalSince1970;
        _relativePath = [KTVHCPathTools relativePathWithAbsoultePath:path];
        _offset = offset;
        [self prepare];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        _createTimeInterval = [[aDecoder decodeObjectForKey:@"createTimeInterval"] doubleValue];
        _relativePath = [aDecoder decodeObjectForKey:@"relativePath"];
        _offset = [[aDecoder decodeObjectForKey:@"offset"] longLongValue];
        [self prepare];
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

- (void)prepare
{
    _absolutePath = [KTVHCPathTools absoultePathWithRelativePath:self.relativePath];
    self.length = [KTVHCPathTools sizeOfItemAtPath:self.absolutePath];
    KTVHCLogDataUnitItem(@"%p, Create Unit Item\nabsolutePath : %@\nrelativePath : %@\nOffset : %lld\nLength : %lld", self, self.absolutePath, self.relativePath, self.offset, self.length);
}

- (void)setLength:(long long)length
{
    [self lock];
    _length = length;
    KTVHCLogDataUnitItem(@"%p, Set length : %lld", self, length);
    [self unlock];
}

- (void)lock
{
    if (!self.coreLock)
    {
        self.coreLock = [[NSRecursiveLock alloc] init];
    }
    [self.coreLock lock];
}

- (void)unlock
{
    [self.coreLock unlock];
}

@end

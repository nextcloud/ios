//
//  KTVHCDataSourceProtocol.h
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KTVHCRange.h"

@protocol KTVHCDataSourceProtocol <NSObject>

- (KTVHCRange)range;

- (BOOL)didPrepared;
- (BOOL)didFinished;
- (BOOL)didClosed;

- (void)prepare;
- (void)close;

- (NSData *)readDataOfLength:(NSUInteger)length;

@end

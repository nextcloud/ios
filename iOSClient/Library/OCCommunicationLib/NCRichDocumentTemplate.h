//
//  NCRichDocumentTemplate.h
//  Nextcloud
//
//  Created by Marino Faggiana on 14/11/2018.
//  Copyright © 2018 TWS. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NCRichDocumentTemplate : NSObject

@property NSInteger idTemplate;
@property (nonatomic, strong) NSString *delete;
@property (nonatomic, strong) NSString *extension;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *preview;
@property (nonatomic, strong) NSString *type;

@end

NS_ASSUME_NONNULL_END

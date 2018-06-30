//
//  PKMacros.h
//  Download
//
//  Created by Pavel on 30/05/15.
//  Copyright (c) 2015 Katunin. All rights reserved.
//

#ifndef Download_PKMacros_h
#define Download_PKMacros_h

#pragma mark - Block helpers

#define BlockSafeRun(block_, ...) do { if ((block_) != NULL) (block_)(__VA_ARGS__); } while (NO)
#define BlockSafeRunEx(defaultValue_, block_, ...) (((block_) != NULL) ? (block_)(__VA_ARGS__) : (defaultValue_))
#define BlockSafeRunOnTargetQueue(queue, block, ...) do { if ((block) != NULL) dispatch_async(queue, ^{ (block)(__VA_ARGS__); }); } while (0)
#define BlockSafeRunOnMainQueue(block, ...) BlockSafeRunOnTargetQueue(dispatch_get_main_queue(), (block), __VA_ARGS__)

#if __has_feature(objc_arc)
#define BlockWeakObject(o) __typeof__(o) __weak
#define BlockWeakSelf BlockWeakObject(self)
#define BlockStrongObject(o) __typeof__(o) __strong
#define BlockStrongSelf BlockStrongObject(self)
#define WeakifySelf BlockWeakSelf ___weakSelf___ = self; do {} while (0)
#define StrongifySelf BlockStrongSelf self = ___weakSelf___; do {} while (0)

#endif // __has_feature(objc_arc)

#define SafeObjClassCast(destClass_, resultObj_, originalObj_) \
destClass_ *resultObj_ = (destClass_ *)originalObj_;\
NSAssert2((resultObj_) == nil || [(resultObj_) isKindOfClass:[destClass_ class]],\
@"Incorrect cast: original object (%@) could not be casted to the destination class (%@)", \
(originalObj_), NSStringFromClass([destClass_ class]))

#define SafeObjProtocolCast(destProtocol_, resultObj_, originalObj_) \
id <destProtocol_> resultObj_ = (id <destProtocol_>)originalObj_;\
NSAssert2((resultObj_) == nil || [(resultObj_) conformsToProtocol:@protocol(destProtocol_)],\
@"Incorrect cast: original object (%@) could not be casted to the destination protocol (%@)", \
(originalObj_), NSStringFromProtocol(@protocol(destProtocol_)))


#endif // Download_PKMacros_h

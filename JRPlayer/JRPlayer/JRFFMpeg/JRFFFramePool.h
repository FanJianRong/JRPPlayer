//
//  JRFFFramePool.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JRFFFrame.h"

@interface JRFFFramePool : NSObject

+ (instancetype)videoPool;
+ (instancetype)audioPool;
+ (instancetype)poolWithCapacity:(NSUInteger)number frameClass:(Class)frameClassName;

- (NSUInteger)count;
- (NSUInteger)unuseCount;
- (NSUInteger)usedCount;

- (__kindof JRFFFrame *)getUnuseFrame;

- (void)flush;

@end

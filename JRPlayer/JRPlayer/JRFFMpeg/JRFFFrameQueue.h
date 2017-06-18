//
//  JRFFFrameQueue.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JRFFFrame.h"

@interface JRFFFrameQueue : NSObject

+ (instancetype)frameQueue;

+ (NSTimeInterval)maxVideoDuration;

+ (NSTimeInterval)sleepTimeIntervalForFull;

+ (NSTimeInterval)sleepTimeIntervalForFullAndPaused;

@property (assign, nonatomic, readonly) int size;
@property (assign, nonatomic, readonly) int packetSize;
@property (assign, nonatomic, readonly) NSUInteger count;
@property (assign, atomic, readonly) NSTimeInterval duration;

@property (assign, nonatomic) NSUInteger minFrameCountForGet;
@property (assign, nonatomic) BOOL ignoreMinFrameCountForGetLimit;

- (void)putFrame:(__kindof JRFFFrame *)frame;
- (void)putSortFrame:(__kindof JRFFFrame *)frame;

- (__kindof JRFFFrame *)getFrameSync;
- (__kindof JRFFFrame *)getFrameAsync;
- (__kindof JRFFFrame *)getFrameAsyncPosition:(NSTimeInterval)position discardFrames:(NSMutableArray <__kindof JRFFFrame *>**)discardFrames;
- (NSTimeInterval)getFirstFramePositionAsync;
- (NSMutableArray <__kindof JRFFFrame *> *)discardFrameBeforPosition:(NSTimeInterval)position;

- (void)flush;
- (void)destory;

@end

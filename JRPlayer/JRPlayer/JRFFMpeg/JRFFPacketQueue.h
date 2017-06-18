//
//  JRFFPacketQueue.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avformat.h"

@interface JRFFPacketQueue : NSObject

+ (instancetype)packetQueueWithTimebase:(NSTimeInterval)timebase;

@property (assign, nonatomic, readonly) NSUInteger count;
@property (assign, nonatomic, readonly) int size;
@property (assign, atomic, readonly) NSTimeInterval duration;
@property (assign, nonatomic, readonly) NSTimeInterval timebase;

- (void)putPacket:(AVPacket)packet duration:(NSTimeInterval)duration;
- (AVPacket)getPacketSync;
- (AVPacket)getPacketAsync;

- (void)flush;
- (void)destroy;

@end

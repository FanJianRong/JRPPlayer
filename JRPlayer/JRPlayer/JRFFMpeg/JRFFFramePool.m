//
//  JRFFFramePool.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFFramePool.h"

@interface JRFFFramePool ()<JRFFFrameDelegate>

@property (copy, nonatomic) Class frameClassName;
@property (strong, nonatomic) NSLock *lock;
@property (strong, nonatomic) JRFFFrame *playingFrame;
@property (strong, nonatomic) NSMutableSet <JRFFFrame *> *unuseFrames;
@property (strong, nonatomic) NSMutableSet <JRFFFrame *> *usedFrames;

@end

@implementation JRFFFramePool

+ (instancetype)videoPool
{
    return [self poolWithCapacity:60 frameClass:NSClassFromString(@"JRFFAVYUVVideoFrame")];
}


+ (instancetype)audioPool
{
    return [self poolWithCapacity:500 frameClass:NSClassFromString(@"JRFFAudioFrame")];
}

+ (instancetype)poolWithCapacity:(NSUInteger)number frameClass:(Class)frameClassName
{
    return [[self alloc] initWithCapacity:number frameClass:frameClassName];
}

- (instancetype)initWithCapacity:(NSUInteger)number frameClass:(Class)frameClassName
{
    if (self = [super init]) {
        self.frameClassName = frameClassName;
        self.lock = [[NSLock alloc] init];
        self.unuseFrames = [NSMutableSet setWithCapacity:number];
        self.usedFrames = [NSMutableSet setWithCapacity:number];
    }
    return self;
}

- (NSUInteger)count
{
    return [self unuseCount] + [self usedCount] + (self.playingFrame ? 1 : 0);
}

- (NSUInteger)unuseCount
{
    return self.unuseFrames.count;
}

- (NSUInteger)usedCount
{
    return self.usedFrames.count;
}

- (__kindof JRFFFrame *)getUnuseFrame
{
    [self.lock lock];
    JRFFFrame *frame;
    if (self.unuseFrames.count > 0) {
        frame = [self.unuseFrames anyObject];
        [self.unuseFrames removeObject:frame];
        [self.usedFrames addObject:frame];
    } else {
        frame = [[self.frameClassName alloc] init];
        frame.delegate = self;
        [self.usedFrames addObject:frame];
    }
    [self.lock unlock];
    return frame;
}

- (void)flush
{
    [self.lock lock];
    [self.usedFrames enumerateObjectsUsingBlock:^(JRFFFrame * _Nonnull obj, BOOL * _Nonnull stop) {
        [self.unuseFrames addObject:obj];
    }];
    [self.usedFrames removeAllObjects];
    [self.lock unlock];
}

- (void)setFrameStartDrawing:(JRFFFrame *)frame
{
    if (!frame) {
        return;
    }
    if (![frame isKindOfClass:self.frameClassName]) {
        return;
    }
    [self.lock lock];
    if (self.playingFrame) {
        [self.unuseFrames addObject:self.playingFrame];
    }
    self.playingFrame = frame;
    [self.usedFrames removeObject:self.playingFrame];
    [self.lock unlock];
}

- (void)setFrameStopDrawing:(JRFFFrame *)frame
{
    if (!frame) {
        return;
    }
    if (![frame isKindOfClass:self.frameClassName]) {
        return;
    }
    [self.lock lock];
    if (self.playingFrame == frame) {
        [self.unuseFrames addObject:self.playingFrame];
        self.playingFrame = nil;
    }
    [self.lock unlock];
}

- (void)setFrameUnuse:(JRFFFrame *)frame
{
    if (!frame) {
        return;
    }
    if (![frame isKindOfClass:self.frameClassName]) {
        return;
    }
    [self.lock lock];
    [self.unuseFrames addObject:frame];
    [self.usedFrames removeObject:frame];
    [self.lock unlock];
}

#pragma mark - JRFFFrameDelegate

- (void)frameDidStartPlaying:(JRFFFrame *)frame
{
    [self setFrameStartDrawing:frame];
}

- (void)frameDidStopPlaying:(JRFFFrame *)frame
{
    [self setFrameStopDrawing:frame];
}

- (void)frameDidCancel:(JRFFFrame *)frame
{
    [self setFrameUnuse:frame];
}

@end

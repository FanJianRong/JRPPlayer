//
//  JRFFFrameQueue.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFFrameQueue.h"

@interface JRFFFrameQueue ()

@property (assign, nonatomic) int size;
@property (assign, nonatomic) int packetSize;
@property (assign, nonatomic) NSUInteger count;
@property (assign, atomic) NSTimeInterval duration;

@property (strong, nonatomic) NSCondition *condition;
@property (strong, nonatomic) NSMutableArray <__kindof JRFFFrame *> *frames;

@property (assign, nonatomic) BOOL destoryToken;

@end

@implementation JRFFFrameQueue

+ (instancetype)frameQueue
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _frames = [NSMutableArray array];
        _condition = [[NSCondition alloc] init];
        _minFrameCountForGet = 1;
        _ignoreMinFrameCountForGetLimit = NO;
    }
    return self;
}

+ (NSTimeInterval)maxVideoDuration
{
    return 1.0;
}

+ (NSTimeInterval)sleepTimeIntervalForFull
{
    return [self maxVideoDuration] / 2.0f;
}

+ (NSTimeInterval)sleepTimeIntervalForFullAndPaused
{
    return [self maxVideoDuration] / 1.1f;
}

- (void)putFrame:(__kindof JRFFFrame *)frame
{
    if (!frame) {
        return;
    }
    [self.condition lock];
    if (self.destoryToken) {
        [self.condition unlock];
        return;
    }
    [self.frames addObject:frame];
    self.duration += frame.duration;
    self.size += frame.size;
    self.packetSize += frame.packetSize;
    
    [self.condition signal];
    [self.condition unlock];
}

- (void)putSortFrame:(__kindof JRFFFrame *)frame
{
    if (!frame) {
        return;
    }
    [self.condition lock];
    if (self.destoryToken) {
        [self.condition unlock];
        return;
    }
    BOOL added = NO;
    if (self.frames.count > 0) {
        for (int i = (int)self.frames.count - 1; i >= 0; i--) {
            JRFFFrame *obj = [self.frames objectAtIndex:i];
            if (frame.position > obj.position) {
                [self.frames insertObject:frame atIndex:i + 1];
                added = YES;
                break;
            }
        }
    }
    if (!added) {
        [self.frames addObject:frame];
        added = YES;
    }
    self.duration += frame.duration;
    self.size += frame.size;
    self.packetSize += frame.packetSize;
    [self.condition signal];
    [self.condition unlock];
}

- (__kindof JRFFFrame *)getFrameSync
{
    [self.condition lock];
    while (self.frames.count < self.minFrameCountForGet &&
           !(self.ignoreMinFrameCountForGetLimit && self.frames.firstObject)) {
        if (self.destoryToken) {
            [self.condition unlock];
            return nil;
        }
        [self.condition wait];
    }
    JRFFFrame *frame = self.frames.firstObject;
    [self.frames removeObjectAtIndex:0];
    self.duration -= frame.duration;
    if (self.duration < 0 || self.count <= 0) {
        self.duration = 0;
    }
    self.size -= frame.size;
    if (self.size <= 0 || self.count <= 0) {
        self.size = 0;
    }
    self.packetSize -= frame.packetSize;
    if (self.packetSize <= 0 || self.count <= 0) {
        self.packetSize = 0;
    }
    [self.condition unlock];
    return frame;
}

- (__kindof JRFFFrame *)getFrameAsync
{
    [self.condition lock];
    if (self.destoryToken || self.frames.count <= 0) {
        [self.condition unlock];
        return nil;
    }
    if (!self.ignoreMinFrameCountForGetLimit && self.frames.count < self.minFrameCountForGet) {
        [self.condition unlock];
        return nil;
    }
    JRFFFrame *frame = self.frames.firstObject;
    [self.frames removeObjectAtIndex:0];
    self.duration -= frame.duration;
    if (self.duration < 0 || self.count <= 0) {
        self.duration = 0;
    }
    self.size -= frame.size;
    if (self.size <= 0 || self.count <= 0) {
        self.size = 0;
    }
    self.packetSize -= frame.packetSize;
    if (self.packetSize <= 0 || self.count <= 0) {
        self.packetSize = 0;
    }
    [self.condition unlock];
    return frame;
}

- (__kindof JRFFFrame *)getFrameAsyncPosition:(NSTimeInterval)position discardFrames:(NSMutableArray <__kindof JRFFFrame *>**)discardFrames
{
    [self.condition lock];
    if (self.destoryToken || self.frames.count <= 0) {
        [self.condition unlock];
        return nil;
    }
    if (!self.ignoreMinFrameCountForGetLimit && self.frames.count < self.minFrameCountForGet) {
        [self.condition unlock];
        return nil;
    }
    JRFFFrame *frame = nil;
    NSMutableArray *temp = [NSMutableArray array];
    for (JRFFFrame *obj in self.frames) {
        if (obj.position + obj.duration < position) {
            [temp addObject:obj];
            self.duration -= obj.duration;
            self.size -= obj.duration;
            self.packetSize -= obj.packetSize;
        } else {
            break;
        }
    }
    if (temp.count > 0) {
        frame = temp.lastObject;
        [self.frames removeObjectsInArray:temp];
        [temp removeObject:frame];
        if (temp.count > 0) {
            * discardFrames = temp;
        }
    } else {
        frame = self.frames.firstObject;
        [self.frames removeObject:frame];
        self.duration -= frame.duration;
        self.size -= frame.size;
        self.packetSize -= frame.packetSize;
    }
    if (self.duration < 0 || self.count <= 0) {
        self.duration = 0;
    }
    if (self.size <= 0 || self.count <= 0) {
        self.size = 0;
    }
    if (self.packetSize <= 0 || self.count <= 0) {
        self.packetSize = 0;
    }
    [self.condition unlock];
    return frame;
}

- (NSTimeInterval)getFirstFramePositionAsync
{
    [self.condition lock];
    if (self.destoryToken || self.frames.count <= 0) {
        [self.condition unlock];
        return -1;
    }
    if (!self.ignoreMinFrameCountForGetLimit && self.frames.count < self.minFrameCountForGet) {
        [self.condition unlock];
        return -1;
    }
    NSTimeInterval time = self.frames.firstObject.position;
    [self.condition unlock];
    return time;
}

- (NSMutableArray <__kindof JRFFFrame *> *)discardFrameBeforPosition:(NSTimeInterval)position
{
    [self.condition lock];
    if (self.destoryToken || self.frames.count <= 0) {
        [self.condition unlock];
        return nil;
    }
    if (!self.ignoreMinFrameCountForGetLimit && self.frames.count < self.minFrameCountForGet) {
        [self.condition unlock];
        return nil;
    }
    NSMutableArray *temp = [NSMutableArray array];
    for (JRFFFrame *obj in self.frames) {
        if (obj.position + obj.duration < position) {
            [temp addObject:obj];
            self.duration -= obj.duration;
            self.size -= obj.size;
            self.packetSize -= obj.packetSize;
        } else {
            break;
        }
    }
    if (temp.count > 0) {
        [self.frames removeObjectsInArray:temp];
    }
    if (self.duration < 0 || self.count <= 0) {
        self.duration = 0;
    }
    if (self.size <= 0 || self.count <= 0) {
        self.size = 0;
    }
    if (self.packetSize <= 0 || self.count <= 0) {
        self.packetSize = 0;
    }
    [self.condition unlock];
    if (temp.count > 0) {
        return temp;
    } else {
        return nil;
    }
}

- (void)flush
{
    [self.condition lock];
    [self.frames removeAllObjects];
    self.duration = 0;
    self.size = 0;
    self.packetSize = 0;
    self.ignoreMinFrameCountForGetLimit = NO;
    [self.condition unlock];
}

- (void)destory
{
    [self flush];
    [self.condition lock];
    self.destoryToken = YES;
    [self.condition broadcast];
    [self.condition unlock];
}

- (NSUInteger)count
{
    return self.frames.count;
}

@end

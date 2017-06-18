//
//  JRFFFrame.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFFrame.h"

@implementation JRFFFrame

- (void)startPlaying
{
    self->_playing = YES;
    if ([self.delegate respondsToSelector:@selector(frameDidStartPlaying:)]) {
        [self.delegate frameDidStartPlaying:self];
    }
}

- (void)stopPlaying
{
    self->_playing = NO;
    if ([self.delegate respondsToSelector:@selector(frameDidStopPlaying:)]) {
        [self.delegate frameDidStopPlaying:self];
    }
}

- (void)cancel
{
    self->_playing = NO;
    if ([self.delegate respondsToSelector:@selector(frameDidCancel:)]) {
        [self.delegate frameDidCancel:self];
    }
}

@end


@implementation JRFFSubtileFrame

- (JRFFFrameType)type
{
    return JRFFFrameTypeSubtitle;
}

@end


@implementation JRFFArtworkFrame

- (JRFFFrameType)type
{
    return JRFFFrameTypeArkwork;
}

@end

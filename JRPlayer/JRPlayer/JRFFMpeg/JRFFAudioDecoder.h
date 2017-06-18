//
//  JRFFAudioDecoder.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/16.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JRFFAudioFrame.h"
#import "avformat.h"

@class JRFFAudioDecoder;
@protocol JRFFAudioDecoderDelegate <NSObject>

- (void)audioDecoder:(JRFFAudioDecoder *)audioDecoder samplingRate:(Float64 *)samplingRate;

- (void)audioDecoder:(JRFFAudioDecoder *)audioDecoder channelCount:(UInt32 *)channelCount;

@end

@interface JRFFAudioDecoder : NSObject

+ (instancetype)decoderWithCodecContext:(AVCodecContext *)codec_context
                               timebase:(NSTimeInterval)timebase
                               delegate:(id<JRFFAudioDecoderDelegate>)delegate;

@property (weak, nonatomic) id<JRFFAudioDecoderDelegate> delegate;

@property (assign, nonatomic, readonly) int size;
@property (assign, nonatomic, readonly) BOOL empty;
@property (assign, nonatomic, readonly) NSTimeInterval duration;


- (JRFFAudioFrame *)getFrameSync;
- (int)putPacket:(AVPacket)packet;

- (void)flush;
- (void)destroy;

@end

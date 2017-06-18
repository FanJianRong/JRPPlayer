//
//  JRFFVideoDecoder.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/7.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avformat.h"
#import "JRFFVideoFrame.h"

@class JRFFVideoDecoder;

@protocol JRFFVideoDecoderDelegate <NSObject>

- (void)videoDecoder:(JRFFVideoDecoder *)videoDecoder didError:(NSError *)error;
- (void)videoDecoder:(JRFFVideoDecoder *)videoDecoder didChangePreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond;

@end

@interface JRFFVideoDecoder : NSObject

+ (instancetype)decoderWithCodecContext:(AVCodecContext *)codec_context
                               timebase:(NSTimeInterval)timebase
                                    fps:(NSTimeInterval)fps
                      codecContextAsync:(BOOL)codecContextAsync
                     videoToolBoxEnable:(BOOL)videoToolBoxEnable
                             retateType:(JRVideoFrameRotateType) rotateType
                               delegate:(id<JRFFVideoDecoderDelegate>)delegate;

@property (weak, nonatomic) id<JRFFVideoDecoderDelegate> delegate;
@property (strong, nonatomic, readonly) NSError *error;

@property (assign, nonatomic, readonly) NSTimeInterval timebase;
@property (assign, nonatomic, readonly) NSTimeInterval fps;

@property (assign, nonatomic, readonly) JRVideoFrameRotateType rotateType;

@property (assign, nonatomic, readonly) BOOL videoToolBoxEnable;
@property (assign, nonatomic, readonly) BOOL videoToolBoxDidOpen;
@property (assign, nonatomic) NSUInteger videoToolBoxMaxDecodeFrameCount;

@property (assign, nonatomic, readonly) BOOL codecContextAsync;
@property (assign, nonatomic) NSUInteger codecContextMaxDacodeFrameCount;

@property (assign, nonatomic, readonly) BOOL decodeSync;
@property (assign, nonatomic, readonly) BOOL decodeAsync;
@property (assign, nonatomic, readonly) BOOL decodeOnMainThread;

@property (assign, nonatomic, readonly) int size;
@property (assign, nonatomic, readonly) BOOL empty;
@property (assign, nonatomic, readonly) NSTimeInterval duration;

@property (assign, nonatomic) BOOL pause;
@property (assign, nonatomic) BOOL endOfFile;

- (JRFFVideoFrame *)getFrameAsync;
- (JRFFVideoFrame *)getFrameAsyncPosition:(NSTimeInterval)position;
- (void)discardFrameBeforPosition:(NSTimeInterval)position;

- (void)putPacket:(AVPacket)packet;

- (void)flush;
- (void)destroy;

- (void)startDecodeThread;

@end

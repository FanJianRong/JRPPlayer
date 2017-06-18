//
//  JRFFDecoder.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/18.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JRFFAudioFrame.h"
#import "JRFFVideoFrame.h"
#import "JRFFTrack.h"

@class JRFFDecoder;

@protocol JRFFDecoderDelegate <NSObject>

@optional

- (void)decoderWillOpenInputStream:(JRFFDecoder *)decoder;
- (void)decoderDidPrepareToDecodeFrames:(JRFFDecoder *)decoder;
- (void)decoderDidEndOfFile:(JRFFDecoder *)decoder;
- (void)decoderDidPlaybackFinished:(JRFFDecoder *)decoder;
- (void)decoder:(JRFFDecoder *)decoder didError:(NSError *)error;


- (void)decoder:(JRFFDecoder *)decoder didChangeValueOfBuffering:(BOOL)buffering;
- (void)decoder:(JRFFDecoder *)decoder didChangeValueOfBufferedDuration:(NSTimeInterval)bufferedDuration;
- (void)decoder:(JRFFDecoder *)decoder didChangeValueOfProgress:(NSTimeInterval)progress;

@end

@protocol JRFFDecoderAudioOutput <NSObject>

- (JRFFAudioFrame *)decoderAudioOutputGetAudioFrame;

@end

@protocol JRFFDecoderAudioOutputConfig <NSObject>

- (Float64)decoderAudioOutputConfigGetSamplingRate;
- (UInt32)decoderAudioOutputConfigGetNumberOfChannels;

@end

@protocol JRFFDecoderVideoOutput <NSObject>

- (JRFFVideoFrame *)decoderVideoOutputGetVideoFrameWithCurrentPosition:(NSTimeInterval)currentPosition
                                                       currentDuration:(NSTimeInterval)currentDuration;

@end

@protocol JRFFDecoderVideoOutputConfig <NSObject>

- (void)decoderVideoOutputConfigDidUpdateMaxPreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond;
- (BOOL)decoderVideoOutputConfigAVCodecContextDecodeAsync;

@end


@interface JRFFDecoder : NSObject<JRFFDecoderAudioOutput, JRFFDecoderVideoOutput>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)decoderWithContentURL:(NSURL *)contentURL
                             delegate:(id <JRFFDecoderDelegate>)delegate
                    videoOutputConfig:(id <JRFFDecoderVideoOutputConfig>)videoOutputConfig
                    audioOutputConfig:(id <JRFFDecoderAudioOutputConfig>)audioOutputConfig;

@property (strong, nonatomic, readonly) NSError *error;

@property (copy, nonatomic, readonly) NSURL *contentURL;

@property (copy, nonatomic, readonly) NSDictionary *metadata;
@property (assign, nonatomic, readonly) CGSize presentationSize;
@property (assign, nonatomic, readonly) CGFloat aspect;
@property (assign, nonatomic, readonly) NSTimeInterval bitrate;
@property (assign, nonatomic, readonly) NSTimeInterval progress;
@property (assign, nonatomic, readonly) NSTimeInterval duration;
@property (assign, nonatomic, readonly) NSTimeInterval bufferedDuration;

@property (assign, nonatomic) NSTimeInterval minBufferedDuration;
@property (assign, nonatomic) BOOL hardwareAccelerateEnable;

@property (assign, nonatomic, readonly) BOOL buffering;

@property (assign, nonatomic, readonly) BOOL playbackFinished;
@property (assign, atomic, readonly) BOOL closed;
@property (assign, atomic, readonly) BOOL endOfFile;
@property (assign, atomic, readonly) BOOL paused;
@property (assign, atomic, readonly) BOOL seeking;
@property (assign, atomic, readonly) BOOL reading;
@property (assign, atomic, readonly) BOOL prepareToDecode;

@property (assign, nonatomic, readonly) BOOL videoDecodeOnMainThread;

@property (strong, nonatomic) NSDictionary *formatContextOptions;
@property (strong, nonatomic) NSDictionary *codecContextOptions;

- (void)pause;
- (void)resume;

@property (assign, nonatomic, readonly) BOOL seekEnable;
- (void)seekToTime:(NSTimeInterval)time;
- (void)seekToTime:(NSTimeInterval)time completeHandler:(void(^)(BOOL finished))completeHandler;

- (void)open;
- (void)closeFile;


#pragma mark - track info

@property (assign, nonatomic, readonly) BOOL videoEnable;
@property (assign, nonatomic, readonly) BOOL audioEnable;

@property (strong, nonatomic, readonly) JRFFTrack *videoTrack;
@property (strong, nonatomic, readonly) JRFFTrack *audioTrack;

@property (strong, nonatomic, readonly) NSArray <JRFFTrack *> *videoTracks;
@property (strong, nonatomic, readonly) NSArray <JRFFTrack *> *audioTracks;

- (void)selectAudioTrackIndex:(int)audioTrackIndex;

@end

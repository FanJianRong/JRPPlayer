//
//  JRFFDecoder.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/18.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFDecoder.h"
#import "JRFFFormatContext.h"
#import "JRFFVideoDecoder.h"
#import "JRFFAudioDecoder.h"
#import "JRFFTools.h"

@interface JRFFDecoder ()<JRFFFormatContextDelegate, JRFFVideoDecoderDelegate, JRFFAudioDecoderDelegate>

@property (weak, nonatomic) id<JRFFDecoderDelegate> delegate;
@property (weak, nonatomic) id<JRFFDecoderVideoOutputConfig> videoOutputConfig;
@property (weak, nonatomic) id<JRFFDecoderAudioOutputConfig> audioOutputConfig;

@property (strong, nonatomic) NSOperationQueue *ffmpegOperationQueue;
@property (strong, nonatomic) NSInvocationOperation *openFileOperation;
@property (strong, nonatomic) NSInvocationOperation *readPacketOperation;
@property (strong, nonatomic) NSInvocationOperation *decodeFrameOperaion;

@property (strong, nonatomic) JRFFFormatContext *formatContext;
@property (strong, nonatomic) JRFFAudioDecoder *audioDecoder;
@property (strong, nonatomic) JRFFVideoDecoder *videoDecoder;

@property (strong, nonatomic) NSError *error;

@property (copy, nonatomic) NSURL *contentURL;

@property (nonatomic, assign) NSTimeInterval progress;
@property (nonatomic, assign) NSTimeInterval bufferedDuration;

@property (nonatomic, assign) BOOL buffering;

@property (nonatomic, assign) BOOL playbackFinished;
@property (atomic, assign) BOOL closed;
@property (atomic, assign) BOOL endOfFile;
@property (atomic, assign) BOOL paused;
@property (atomic, assign) BOOL seeking;
@property (atomic, assign) BOOL reading;
@property (atomic, assign) BOOL prepareToDecode;

@property (assign, nonatomic) NSTimeInterval seekToTime;
@property (assign, nonatomic) NSTimeInterval seekMinTime;
@property (copy, nonatomic) void(^seekCompleteHandler)(BOOL finished);

@property (assign, nonatomic) BOOL selectAudioTrack;
@property (assign, nonatomic) int selectAudioTrackIndex;

@property (assign, atomic) NSTimeInterval audioFrameTimeClock;
@property (assign, atomic) NSTimeInterval audioFramePosition;
@property (assign, atomic) NSTimeInterval audioFrameDuration;

@property (assign, atomic) NSTimeInterval videoFrameTimeClock;
@property (assign, atomic) NSTimeInterval videoFramePosition;
@property (assign, atomic) NSTimeInterval videoFrameDuration;

@end



@implementation JRFFDecoder

+ (instancetype)decoderWithContentURL:(NSURL *)contentURL
                             delegate:(id<JRFFDecoderDelegate>)delegate
                    videoOutputConfig:(id<JRFFDecoderVideoOutputConfig>)videoOutputConfig
                    audioOutputConfig:(id<JRFFDecoderAudioOutputConfig>)audioOutputConfig
{
    return [[self alloc] initWithContentURL:contentURL delegate:delegate videoOutputConfig:videoOutputConfig audioOutputConfig:audioOutputConfig];
}

- (instancetype)initWithContentURL:(NSURL *)contentURL
                          delegate:(id<JRFFDecoderDelegate>)delegate
                 videoOutputConfig:(id<JRFFDecoderVideoOutputConfig>)videoOutputConfig
                 audioOutputConfig:(id<JRFFDecoderAudioOutputConfig>)audioOutputConfig
{
    if (self = [super init]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            av_log_set_callback(JRFFLog);
            av_register_all();
            avformat_network_init();
        });
        self.contentURL = contentURL;
        self.delegate = delegate;
        self.videoOutputConfig = videoOutputConfig;
        self.audioOutputConfig = audioOutputConfig;
        
        self.hardwareAccelerateEnable = YES;
    }
    return self;
}

#pragma mark - operation

- (void)open
{
    [self setupOperationQueue];
}

- (void)setupOperationQueue
{
    self.ffmpegOperationQueue = [[NSOperationQueue alloc] init];
    self.ffmpegOperationQueue.maxConcurrentOperationCount = 2;
    self.ffmpegOperationQueue.qualityOfService = NSQualityOfServiceUserInitiated;
    
    [self setupOpenFileOperation];
}

- (void)setupOpenFileOperation
{
    self.openFileOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(openFormatContext) object:nil];
    self.openFileOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
    self.openFileOperation.qualityOfService = NSQualityOfServiceUserInitiated;
    
    [self.ffmpegOperationQueue addOperation:self.openFileOperation];
}

- (void)setupReadPacketOperation
{
    if (self.error) {
        [self delegateErrorCallback];
        return;
    }
    
    if (!self.readPacketOperation || self.readPacketOperation.isFinished) {
        self.readPacketOperation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                        selector:@selector(readPacketThread)
                                                                          object:nil];
        self.readPacketOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
        self.readPacketOperation.qualityOfService = NSQualityOfServiceUserInitiated;
        [self.readPacketOperation addDependency:self.openFileOperation];
        [self.ffmpegOperationQueue addOperation:self.readPacketOperation];
    }
    
    if (self.formatContext.videoEnable) {
        if (!self.decodeFrameOperaion || self.decodeFrameOperaion.isFinished) {
            self.decodeFrameOperaion = [[NSInvocationOperation alloc] initWithTarget:self.videoDecoder
                                                                            selector:@selector(startDecodeThread)
                                                                              object:nil];
            self.decodeFrameOperaion.queuePriority = NSOperationQueuePriorityVeryHigh;
            self.decodeFrameOperaion.qualityOfService = NSQualityOfServiceUserInitiated;
            [self.decodeFrameOperaion addDependency:self.openFileOperation];
            [self.ffmpegOperationQueue addOperation:self.decodeFrameOperaion];
        }
    }
    
}


#pragma mark - open stream

- (void)openFormatContext
{
    if ([self.delegate respondsToSelector:@selector(decoderWillOpenInputStream:)]) {
        [self.delegate decoderWillOpenInputStream:self];
    }
    
    self.formatContext = [JRFFFormatContext formatContextWithContentURL:self.contentURL delegae:self];
    self.formatContext.formatContextOptions = self.formatContextOptions;
    self.formatContext.codecContextOptions = self.codecContextOptions;
    [self.formatContext setupSync];
    
    if (self.formatContext.error) {
        self.error = self.formatContext.error;
        [self delegateErrorCallback];
        return;
    }
    
    self.prepareToDecode = YES;
    if ([self.delegate respondsToSelector:@selector(decoderDidPrepareToDecodeFrames:)]) {
        [self.delegate decoderDidPrepareToDecodeFrames:self];
    }
    
    if (self.formatContext.videoEnable) {
        self.videoDecoder = [JRFFVideoDecoder decoderWithCodecContext:self.formatContext->_video_codec_context
                                                             timebase:self.formatContext.videoTimebase
                                                                  fps:self.formatContext.videoFPS
                                                    codecContextAsync:[self.videoOutputConfig decoderVideoOutputConfigAVCodecContextDecodeAsync]
                                                   videoToolBoxEnable:self.hardwareAccelerateEnable
                                                           retateType:self.formatContext.videoFrameRotateType
                                                             delegate:self];
    }
    if (self.formatContext.audioEnable) {
        self.audioDecoder = [JRFFAudioDecoder decoderWithCodecContext:self.formatContext->_audio_codec_context
                                                             timebase:self.formatContext.audioTimebase
                                                             delegate:self];
    }
    [self setupReadPacketOperation];
}

#pragma mark - close stream

- (void)closeFile
{
    [self closeFileAsync:YES];
}

- (void)closeFileAsync:(BOOL)async
{
    if (!self.closed) {
        self.closed = YES;
        [self.videoDecoder destroy];
        [self.audioDecoder destroy];
        if (async) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                [self.ffmpegOperationQueue cancelAllOperations];
                [self.ffmpegOperationQueue waitUntilAllOperationsAreFinished];
                [self closePropertyValue];
                [self.formatContext destroy];
                [self closeOperation];
            });
        } else {
            [self.ffmpegOperationQueue cancelAllOperations];
            [self.ffmpegOperationQueue waitUntilAllOperationsAreFinished];
            [self closePropertyValue];
            [self.formatContext destroy];
            [self closeOperation];
        }
    }
}

- (void)closePropertyValue
{
    self.seeking = NO;
    self.buffering = NO;
    self.paused = NO;
    self.prepareToDecode = NO;
    self.endOfFile = NO;
    self.playbackFinished = NO;
    [self cleanAudioFrame];
    [self cleanVideoFrame];
    self.videoDecoder.pause = NO;
    self.videoDecoder.endOfFile = NO;
    self.selectAudioTrack = NO;
    self.selectAudioTrackIndex = 0;
}

- (void)closeOperation
{
    self.readPacketOperation = nil;
    self.openFileOperation = nil;
    self.decodeFrameOperaion = nil;
    self.ffmpegOperationQueue = nil;
}

- (void)cleanAudioFrame
{
    self.audioFrameTimeClock = -1;
    self.audioFramePosition = -1;
    self.audioFrameDuration = -1;
}

- (void)cleanVideoFrame
{
    self.videoFrameTimeClock = -1;
    self.videoFramePosition = -1;
    self.videoFrameDuration = -1;
}


#pragma mark - operation thread

static int max_packet_buffer_size = 15 * 1024 * 1024;
static NSTimeInterval max_packet_sleep_full_time_interval = 0.1;
static NSTimeInterval max_packet_sleep_full_and_pause_time_interval = 0.5;

- (void)readPacketThread
{
    [self cleanVideoFrame];
    [self cleanAudioFrame];
    
    [self.videoDecoder flush];
    [self.audioDecoder flush];
    
    self.reading = YES;
    BOOL finished = NO;
    AVPacket packet;
    
    while (!finished) {
        if (self.closed || self.error) {
            NSLog(@"read packet thread quit");
            break;
        }
        if (self.seeking) {
            self.endOfFile = NO;
            self.playbackFinished = NO;
            
            [self.formatContext seekFileWithFFTimebase:self.seekToTime];
            
            self.buffering = YES;
            [self.audioDecoder flush];
            [self.videoDecoder flush];
            self.videoDecoder.pause = NO;
            self.videoDecoder.endOfFile = NO;
            self.seeking = NO;
            self.seekToTime = 0;
            if (self.seekCompleteHandler) {
                self.seekCompleteHandler(YES);
                self.seekCompleteHandler = nil;
            }
            [self cleanVideoFrame];
            [self cleanAudioFrame];
            [self updateBufferedDurationByAudio];
            [self updateBufferedDurationByVideo];
            continue;
        }
        if (self.selectAudioTrack) {
            NSError *selectResult = [self.formatContext selectAudioTrackIndex:self.selectAudioTrackIndex];
            if (!selectResult) {
                [self.audioDecoder destroy];
                self.audioDecoder = [JRFFAudioDecoder decoderWithCodecContext:self.formatContext->_audio_codec_context
                                                                     timebase:self.formatContext.audioTimebase
                                                                     delegate:self];
                if (!self.playbackFinished) {
                    [self seekToTime:self.progress];
                }
            }
            self.selectAudioTrack = NO;
            self.selectAudioTrackIndex = 0;
            continue;
        }
        if (self.audioDecoder.size + self.videoDecoder.size >= max_packet_buffer_size) {
            NSTimeInterval interval = 0;
            if (self.paused) {
                interval = max_packet_sleep_full_and_pause_time_interval;
            } else {
                interval = max_packet_sleep_full_time_interval;
            }
            NSLog(@"read thread sleep : %f", interval);
            [NSThread sleepForTimeInterval:interval];
            continue;
        }
        
        //read frame
        int result = [self.formatContext readFrame:&packet];
        if (result < 0) {
            NSLog(@"read packet finished");
            self.endOfFile = YES;
            self.videoDecoder.endOfFile = YES;
            finished = YES;
            if ([self.delegate respondsToSelector:@selector(decoderDidEndOfFile:)]) {
                [self.delegate decoderDidEndOfFile:self];
            }
            break;
        }
        if (packet.stream_index == self.formatContext.videoTrack.index && self.formatContext.videoEnable) {
            NSLog(@"video : put packet");
            [self.videoDecoder putPacket:packet];
            [self updateBufferedDurationByVideo];
        } else if(packet.stream_index == self.formatContext.audioTrack.index && self.formatContext.audioEnable) {
            NSLog(@"audio : put packet");
            int result = [self.audioDecoder putPacket:packet];
            if (result < 0) {
                self.error = JRFFCheckErrorCode(result, JRFFDecoderErrorCodeCodecAudioSendPacket);
                [self delegateErrorCallback];
                continue;
            }
            [self updateBufferedDurationByAudio];
        }
    }
    self.reading = NO;
    [self checkBufferingStatus];
}

- (void)pause
{
    self.paused = YES;
}

- (void)resume
{
    self.paused = NO;
    if (self.playbackFinished) {
        [self seekToTime:0];
    }
}

- (void)seekToTime:(NSTimeInterval)time
{
    [self seekToTime:time completeHandler:nil];
}

- (void)seekToTime:(NSTimeInterval)time completeHandler:(void (^)(BOOL))completeHandler
{
    if (!self.seekEnable || self.error) {
        if (completeHandler) {
            completeHandler(NO);
        }
        return;
    }
    NSTimeInterval tempDuration = 8;
    if (!self.formatContext.audioEnable) {
        tempDuration = 15;
    }
    
    NSTimeInterval seekMaxTime = self.duration - (self.minBufferedDuration + tempDuration);
    if (seekMaxTime < self.seekMinTime) {
        seekMaxTime = self.seekMinTime;
    }
    if (time > seekMaxTime) {
        time = seekMaxTime;
    } else if (time < self.seekMinTime) {
        time = self.seekMinTime;
    }
    self.progress = time;
    self.seekToTime = time;
    self.seekCompleteHandler = completeHandler;
    self.seeking = YES;
    self.videoDecoder.pause = YES;
    
    if (self.endOfFile) {
        [self setupReadPacketOperation];
    }
}

- (JRFFAudioFrame *)decoderAudioOutputGetAudioFrame
{
    BOOL check = self.closed || self.seeking || self.buffering || self.paused || self.playbackFinished || !self.formatContext.audioEnable;
    if (check) {
        return nil;
    }
    if (self.audioDecoder.empty) {
        [self updateBufferedDurationByAudio];
        return nil;
    }
    JRFFAudioFrame *audioFrame = [self.audioDecoder getFrameSync];
    if (!audioFrame) {
        return nil;
    }
    self.audioFramePosition = audioFrame.position;
    self.audioFrameDuration = audioFrame.duration;
    
    if (self.endOfFile) {
        [self updateBufferedDurationByAudio];
    }
    [self updateProgressByAudio];
    self.audioFrameTimeClock = [NSDate date].timeIntervalSince1970;
    return audioFrame;
}

- (JRFFVideoFrame *)decoderVideoOutputGetVideoFrameWithCurrentPosition:(NSTimeInterval)currentPosition
                                                       currentDuration:(NSTimeInterval)currentDuration
{
    if (self.closed || self.error) {
        return nil;
    }
    if (self.seeking || self.buffering) {
        return nil;
    }
    if (self.paused && self.videoFrameTimeClock > 0) {
        return nil;
    }
    if (self.audioEnable && self.audioFrameTimeClock < 0 && self.videoFrameTimeClock > 0) {
        return nil;
    }
    if (self.videoDecoder.empty) {
        return nil;
    }
    NSTimeInterval timeinterval = [NSDate date].timeIntervalSince1970;
    JRFFVideoFrame *videoFrame = nil;
    if (self.formatContext.audioEnable) {
        if (self.videoFrameTimeClock < 0) {
            videoFrame = [self.videoDecoder getFrameAsync];
        } else {
            NSTimeInterval audioTimeClock = self.audioFrameTimeClock;
            NSTimeInterval audioClockDelta = timeinterval - audioTimeClock;
            NSTimeInterval audioPositionReal = self.audioFramePosition + audioClockDelta;
            NSTimeInterval currentStop = currentPosition + currentDuration;
            
            if (currentStop <= audioPositionReal) {
                videoFrame = [self.videoDecoder getFrameAsyncPosition:currentPosition];
            }
        }
    } else if (self.formatContext.videoEnable) {
        if (self.videoFrameTimeClock < 0 || timeinterval >= self.videoFrameTimeClock + self.videoFrameDuration) {
            videoFrame = [self.videoDecoder getFrameAsync];
        }
    }
    if (videoFrame) {
        self.videoFrameTimeClock = timeinterval;
        self.videoFrameDuration = videoFrame.duration;
        self.videoFramePosition = videoFrame.position;
        [self updateProgressByVideo];
        if (self.endOfFile) {
            [self updateBufferedDurationByVideo];
        }
    }
    return videoFrame;
}

#pragma mark - setter && getter

- (void)setProgress:(NSTimeInterval)progress
{
    if (_progress != progress) {
        _progress = progress;
        if ([self.delegate respondsToSelector:@selector(decoder:didChangeValueOfProgress:)]) {
            [self.delegate decoder:self didChangeValueOfProgress:progress];
        }
    }
}

- (void)setBuffering:(BOOL)buffering
{
    if (!_buffering != buffering) {
        _buffering = buffering;
        if ([self.delegate respondsToSelector:@selector(decoder:didChangeValueOfBuffering:)]) {
            [self.delegate decoder:self didChangeValueOfBuffering:_buffering];
        }
    }
}

- (void)setPlaybackFinished:(BOOL)playbackFinished
{
    if (_playbackFinished != playbackFinished) {
        _playbackFinished = playbackFinished;
        if (_playbackFinished) {
            self.progress = self.duration;
            if ([self.delegate respondsToSelector:@selector(decoderDidPlaybackFinished:)]) {
                [self.delegate decoderDidPlaybackFinished:self];
            }
        }
    }
}

- (void)setBufferedDuration:(NSTimeInterval)bufferedDuration
{
    if (_bufferedDuration != bufferedDuration) {
        _bufferedDuration = bufferedDuration;
        if (_bufferedDuration <= 0.000001) {
            _bufferedDuration = 0;
        }
        if ([self.delegate respondsToSelector:@selector(decoder:didChangeValueOfBufferedDuration:)]) {
            [self.delegate decoder:self didChangeValueOfBufferedDuration:_bufferedDuration];
        }
        if (_bufferedDuration <= 0 && self.endOfFile) {
            self.playbackFinished = YES;
        }
        [self checkBufferingStatus];
    }
}

- (NSDictionary *)metadata
{
    return self.formatContext.metadata;
}

- (NSTimeInterval)duration
{
    return self.formatContext.duration;
}

- (NSTimeInterval)bitrate
{
    return self.formatContext.bitrate;
}

- (BOOL)seekEnable
{
    return self.formatContext.seekEnable;
}

- (CGSize)presentationSize
{
    return self.formatContext.videoPresentationSize;
}

- (CGFloat)aspect
{
    return self.formatContext.videoAspect;
}

- (BOOL)videoDecodeOnMainThread
{
    return  self.videoDecoder.decodeOnMainThread;
}


#pragma mark - delegate callback

- (void)checkBufferingStatus
{
    if (self.buffering) {
        if (self.bufferedDuration >= self.minBufferedDuration || self.endOfFile) {
            self.buffering = NO;
        }
    } else {
        if (self.bufferedDuration <= 0.2 && !self.endOfFile) {
            self.buffering = YES;
        }
    }
}

- (void)delegateErrorCallback
{
    if (self.error) {
        if ([self.delegate respondsToSelector:@selector(decoder:didError:)]) {
            [self.delegate decoder:self didError:self.error];
        }
    }
}

- (void)updateBufferedDurationByVideo
{
    if (!self.formatContext.audioEnable) {
        self.bufferedDuration = self.videoDecoder.duration;
    }
}

- (void)updateBufferedDurationByAudio
{
    if (self.formatContext.audioEnable) {
        self.bufferedDuration = self.audioDecoder.duration;
    }
}

- (void)updateProgressByVideo
{
    if (!self.formatContext.audioEnable && self.formatContext.videoEnable) {
        if (self.videoFramePosition > 0) {
            self.progress = self.videoFramePosition;
        } else {
            self.progress = 0;
        }
    }
}

- (void)updateProgressByAudio
{
    if (self.formatContext.audioEnable) {
        if (self.audioFramePosition > 0) {
            self.progress = self.audioFramePosition;
        } else {
            self.progress = 0;
        }
    }
}

- (void)dealloc
{
    [self closeFileAsync:NO];
    NSLog(@"JRFFDecoder release");
}

#pragma mark - delegate callback

- (BOOL)formatContextNeedInterrupt:(JRFFFormatContext *)formatContext
{
    return self.closed;
}

- (void)audioDecoder:(JRFFAudioDecoder *)audioDecoder samplingRate:(Float64 *)samplingRate
{
    if ([self.audioOutputConfig respondsToSelector:@selector(decoderAudioOutputConfigGetSamplingRate)]) {
        * samplingRate = [self.audioOutputConfig decoderAudioOutputConfigGetSamplingRate];
    }
}

- (void)audioDecoder:(JRFFAudioDecoder *)audioDecoder channelCount:(UInt32 *)channelCount
{
    if ([self.audioOutputConfig respondsToSelector:@selector(decoderAudioOutputConfigGetNumberOfChannels)]) {
        * channelCount = [self.audioOutputConfig decoderAudioOutputConfigGetNumberOfChannels];
    }
}

- (void)videoDecoder:(JRFFVideoDecoder *)videoDecoder didError:(NSError *)error
{
    self.error = error;
    [self delegateErrorCallback];
}

- (void)videoDecoder:(JRFFVideoDecoder *)videoDecoder didChangePreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond
{
    if ([self.videoOutputConfig respondsToSelector:@selector(decoderVideoOutputConfigDidUpdateMaxPreferredFramesPerSecond:)]) {
        [self.videoOutputConfig decoderVideoOutputConfigDidUpdateMaxPreferredFramesPerSecond:preferredFramesPerSecond];
    }
}

#pragma mark - track info

- (BOOL)videoEnable
{
    return self.formatContext.videoEnable;
}

- (BOOL)audioEnable
{
    return self.formatContext.audioEnable;
}

- (JRFFTrack *)videoTrack
{
    return self.formatContext.videoTrack;
}

- (JRFFTrack *)audioTrack
{
    return self.formatContext.audioTrack;
}

- (NSArray<JRFFTrack *> *)videoTracks
{
    return self.formatContext.videoTracks;
}

- (NSArray<JRFFTrack *> *)audioTracks
{
    return self.formatContext.audioTracks;
}

- (void)selectAudioTrackIndex:(int)audioTrackIndex
{
    if (self.formatContext.audioTrack.index == audioTrackIndex) {
        return;
    }
    if (![self.formatContext containAudioTrack:audioTrackIndex]) {
        return;
    }
    self.selectAudioTrack = YES;
    self.selectAudioTrackIndex = audioTrackIndex;
    if (self.endOfFile) {
        [self setupReadPacketOperation];
    }
}

@end

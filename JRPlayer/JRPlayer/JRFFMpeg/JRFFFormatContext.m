//
//  JRFFFormatContext.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/17.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFFormatContext.h"

static int ffmpeg_interrupt_callback(void *ctx)
{
    JRFFFormatContext *obj = (__bridge JRFFFormatContext *)ctx;
    return [obj.delegate formatContextNeedInterrupt:obj];
}

@interface JRFFFormatContext ()

@property (copy, nonatomic) NSURL *contentURL;

@property (copy, nonatomic) NSError *error;
@property (copy, nonatomic) NSDictionary *metadata;

@property (assign, nonatomic) BOOL videoEnable;
@property (assign, nonatomic) BOOL audioEnable;

@property (strong, nonatomic) JRFFTrack *videoTrack;
@property (strong, nonatomic) JRFFTrack *audioTrack;

@property (strong, nonatomic) NSArray <JRFFTrack *> *videoTracks;
@property (strong, nonatomic) NSArray <JRFFTrack *> *audioTracks;

@property (assign, nonatomic) NSTimeInterval videoTimebase;
@property (assign, nonatomic) NSTimeInterval videoFPS;
@property (assign, nonatomic) CGSize videoPresentationSize;
@property (assign, nonatomic) CGFloat videoAspect;

@property (assign, nonatomic) NSTimeInterval audioTimebase;

@end


@implementation JRFFFormatContext

+ (instancetype)formatContextWithContentURL:(NSURL *)contentURL delegae:(id<JRFFFormatContextDelegate>)delegate
{
    return [[self alloc] initWithContentURL:contentURL delegae:delegate];
}

- (instancetype)initWithContentURL:(NSURL *)contentURL delegae:(id<JRFFFormatContextDelegate>)delegate
{
    if (self = [super init]) {
        self.contentURL = contentURL;
        self.delegate = delegate;
    }
    return self;
}

- (void)setupSync
{
    self.error = [self openSteam];
    if (self.error) {
        return;
    }
    [self openTracks];
    NSError *videoError = [self openVideoTrack];
    NSError *audioError = [self openAudioTrack];
    
    if (videoError && audioError) {
        if (videoError.code == JRFFDecoderErrorCodeStreamNotFound && audioError.code != JRFFDecoderErrorCodeStreamNotFound) {
            self.error = audioError;
        } else {
            self.error = videoError;
        }
        return;
    }
    
}

- (NSError *)openSteam
{
    int result = 0;
    NSError *error = nil;
    
    self->_format_context = avformat_alloc_context();
    if (!_format_context) {
        result = -1;
        error = [NSError errorWithDomain:@"JRFFDecoderErrorCodeFormatCreate error" code:JRFFDecoderErrorCodeFormatCreate userInfo:nil];
        return error;
    }
    _format_context->interrupt_callback.callback = ffmpeg_interrupt_callback;
    _format_context->interrupt_callback.opaque = (__bridge void *)self;
    
    AVDictionary *options = JRFFFFmpegBrigeOfNSDictionary(self.formatContextOptions);
    
    // options filter.
    NSString *URLString = [self contentURLString];
    NSString *lowercaseURLString = [URLString lowercaseString];
    if ([lowercaseURLString hasPrefix:@"rtmp"] || [lowercaseURLString hasPrefix:@"rtsp"]) {
        av_dict_set(&options, "timeout", NULL, 0);
    }
    result = avformat_open_input(&_format_context, URLString.UTF8String, NULL, &options);
    if (options) {
        av_dict_free(&options);
    }
    error = JRFFCheckErrorCode(result, JRFFDecoderErrorCodeFormatOpenInput);
    if (error || !_format_context) {
        if (_format_context) {
            avformat_free_context(_format_context);
        }
        return error;
    }
    result = avformat_find_stream_info(_format_context, NULL);
    if (error || !_format_context) {
        if (_format_context) {
            avformat_close_input(&_format_context);
        }
        return error;
    }
    self.metadata = JRFFFoundationBrigeOfAVDictionary(_format_context->metadata);
    
    return error;
}

- (void)openTracks
{
    NSMutableArray <JRFFTrack *> * videoTracks = [NSMutableArray array];
    NSMutableArray <JRFFTrack *> * audioTracks = [NSMutableArray array];
    
    for (int i = 0; i < _format_context->nb_streams; i++) {
        AVStream *stream = _format_context->streams[i];
        switch (stream->codecpar->codec_type) {
            case AVMEDIA_TYPE_VIDEO:
            {
                JRFFTrack *track = [[JRFFTrack alloc] init];
                track.type = JRFFTrackTypeVideo;
                track.index = i;
                track.metadata = [JRFFMetadata metadataWithAVDictionary:stream->metadata];
                [videoTracks addObject:track];
            }
                break;
            case AVMEDIA_TYPE_AUDIO:
            {
                JRFFTrack *track = [[JRFFTrack alloc] init];
                track.type = JRFFTrackTypeAudio;
                track.index = i;
                track.metadata = [JRFFMetadata metadataWithAVDictionary:stream->metadata];
                [audioTracks addObject:track];
            }
                break;
            default:
                break;
        }
        if (videoTracks.count > 0) {
            self.videoTracks = videoTracks;
        }
        if (audioTracks.count > 0) {
            self.audioTracks = audioTracks;
        }
    }
}

- (NSError *)openVideoTrack
{
    NSError *error = nil;
    
    if (self.videoTracks.count > 0) {
        for (JRFFTrack *obj in self.videoTracks) {
            int index = obj.index;
            if ((_format_context->streams[index]->disposition & AV_DISPOSITION_ATTACHED_PIC) == 0) {
                
                AVCodecContext *codec_context;
                error = [self openStreamWithTrackIndex:index codecContext:&codec_context domain:@"video"];
                if (!error) {
                    self.videoTrack = obj;
                    self.videoEnable = YES;
                    self.videoTimebase = JRFFStreamGetTimebase(_format_context->streams[index], 0.00004);
                    self.videoFPS = JRFFStreamGetFPS(_format_context->streams[index], self.videoTimebase);
                    self.videoPresentationSize = CGSizeMake(codec_context->width, codec_context->height);
                    self.videoAspect = (CGFloat)codec_context->width / (CGFloat)codec_context->height;
                    self->_video_codec_context = codec_context;
                    break;
                }
            }
        }
    } else {
        error = [NSError errorWithDomain:@"video stream not found" code:JRFFDecoderErrorCodeStreamNotFound userInfo:nil];
        return error;
    }
    return error;
}

- (NSError *)openAudioTrack
{
    NSError *error = nil;
    
    if (self.audioTracks.count > 0) {
        for (JRFFTrack *obj in self.audioTracks) {
            
            int index = obj.index;
            AVCodecContext *codec_context;
            error = [self openStreamWithTrackIndex:index codecContext:&codec_context domain:@"audio"];
            if (!error) {
                self.audioTrack = obj;
                self.audioEnable = YES;
                self.audioTimebase = JRFFStreamGetTimebase(_format_context->streams[index], 0.000025);
                self->_audio_codec_context = codec_context;
                break;
            }
        }
    } else {
        error = [NSError errorWithDomain:@"audio stream not found" code:JRFFDecoderErrorCodeStreamNotFound userInfo:nil];
        return error;
    }
    return error;
}


- (NSError *)openStreamWithTrackIndex:(int)trackIndex codecContext:(AVCodecContext **)codecContext domain:(NSString *)domain
{
    int result = 0;
    NSError *error = nil;
    
    AVStream *stream = _format_context->streams[trackIndex];
    AVCodecContext *codec_context = avcodec_alloc_context3(NULL);
    if (!codecContext) {
        error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@ codec context create error", domain]
                                    code:JRFFDecoderErrorCodeCodecContextCreate
                                userInfo:nil];
        return error;
    }
    result = avcodec_parameters_to_context(codec_context, stream->codecpar);
    error = JRFFCheckErrorCode(result, JRFFDecoderErrorCodeCodecContextSetParam);
    if (error) {
        avcodec_free_context(&codec_context);
        return error;
    }
    av_codec_set_pkt_timebase(codec_context, stream->time_base);
    
    AVCodec *codec = avcodec_find_decoder(codec_context->codec_id);
    if (!codec) {
        avcodec_free_context(&codec_context);
        error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@ codec not found decoder", domain]
                                    code:JRFFDecoderErrorCodeCodecFindDecoder
                                userInfo:nil];
        return error;
    }
    codec_context->codec_id = codec->id;
    
    AVDictionary *options = JRFFFFmpegBrigeOfNSDictionary(self.codecContextOptions);
    if (!av_dict_get(options, "threads", NULL, 0)) {
        av_dict_set(&options, "threads", "auto", 0);
    }
    if (codec_context->codec_type == AVMEDIA_TYPE_VIDEO || codec_context->codec_type == AVMEDIA_TYPE_AUDIO) {
        av_dict_set(&options, "refcounted_frames", "1", 0);
    }
    result = avcodec_open2(codec_context, codec, &options);
    error = JRFFCheckErrorCode(result, JRFFDecoderErrorCodeCodecOpen2);
    if (error) {
        avcodec_free_context(&codec_context);
        return error;
    }
    * codecContext = codec_context;
    return error;
}


- (NSString *)contentURLString
{
    if ([self.contentURL isFileURL]) {
        return [self.contentURL path];
    } else {
        return [self.contentURL absoluteString];
    }
}

- (void)destroy
{
    [self destroyAudioTrack];
    [self destroyVideoTrack];
    if (_format_context) {
        avformat_close_input(&_format_context);
        _format_context = NULL;
    }
}

- (void)destroyAudioTrack
{
    self.audioEnable = NO;
    self.audioTrack = nil;
    self.audioTracks = nil;
    
    if (_audio_codec_context) {
        avcodec_close(_audio_codec_context);
        _audio_codec_context = NULL;
    }
}

- (void)destroyVideoTrack
{
    self.videoEnable = NO;
    self.videoTrack = nil;
    self.videoTracks = nil;
    
    if (_video_codec_context) {
        avcodec_close(_video_codec_context);
        _video_codec_context = NULL;
    }
}

- (BOOL)seekEnable
{
    if (!self->_format_context) {
        return NO;
    }
    BOOL ioSeekable = YES;
    if (self->_format_context->pb) {
        ioSeekable = self->_format_context->pb->seekable;
    }
    if (ioSeekable && self.duration > 0) {
        return YES;
    }
    return NO;
}

- (void)seekFileWithFFTimebase:(NSTimeInterval)time
{
    int64_t ts = time * AV_TIME_BASE;
    av_seek_frame(self->_format_context, -1, ts, AVSEEK_FLAG_BACKWARD);
}

- (void)seekFileWithVideo:(NSTimeInterval)time
{
    if (self.videoEnable)
    {
        int64_t ts = time * 1000.0 / self.videoTimebase;
        av_seek_frame(self->_format_context, -1, ts, AVSEEK_FLAG_BACKWARD);
    }
    else
    {
        [self seekFileWithFFTimebase:time];
    }
}

- (void)seekFileWithAudio:(NSTimeInterval)time
{
    if (self.audioTimebase)
    {
        int64_t ts = time * 1000 / self.audioTimebase;
        av_seek_frame(self->_format_context, -1, ts, AVSEEK_FLAG_BACKWARD);
    }
    else
    {
        [self seekFileWithFFTimebase:time];
    }
}

- (int)readFrame:(AVPacket *)packet
{
    return av_read_frame(_format_context, packet);
}

- (BOOL)containAudioTrack:(int)audioTrackIndex
{
    for (JRFFTrack *obj in self.audioTracks) {
        if (obj.index == audioTrackIndex) {
            return YES;
        }
    }
    return NO;
}

- (NSError *)selectAudioTrackIndex:(int)audioTrakIndex
{
    if (audioTrakIndex == self.audioTrack.index) {
        return nil;
    }
    if (![self containAudioTrack:audioTrakIndex]) {
        return nil;
    }
    AVCodecContext *codec_context;
    NSError *error = [self openStreamWithTrackIndex:audioTrakIndex codecContext:&codec_context domain:@"audio select"];
    if (!error) {
        if (_audio_codec_context) {
            avcodec_close(_audio_codec_context);
            _audio_codec_context = NULL;
        }
        for (JRFFTrack *obj in self.audioTracks) {
            if (obj.index == audioTrakIndex) {
                self.audioTrack = obj;
            }
        }
        self.audioEnable = YES;
        self.audioTimebase = JRFFStreamGetTimebase(_format_context->streams[audioTrakIndex], 0.000025);
        self->_audio_codec_context = codec_context;
    } else {
        NSLog(@"select audio track error : %@", error);
    }
    return error;
}

- (NSTimeInterval)duration
{
    if (!self->_format_context) {
        return 0;
    }
    int64_t duration = self->_format_context->duration;
    if (duration < 0) {
        return 0;
    }
    return (NSTimeInterval)duration / AV_TIME_BASE;
}

- (NSTimeInterval)bitrate
{
    if (!self->_format_context) {
        return 0;
    }
    return (self->_format_context->bit_rate / 1000.0f);
}

- (JRVideoFrameRotateType)videoFrameRotateType
{
    int rotate = [[self.videoTrack.metadata.metadata objectForKey:@"rotate"] intValue];
    if (rotate == 90) {
        return JRVideoFrameRotateType90;
    } else if (rotate == 180) {
        return JRVideoFrameRotateType180;
    } else if (rotate == 270) {
        return JRVideoFrameRotateType270;
    }
    return JRVideoFrameRotateType0;
}

- (void)dealloc
{
    [self destroy];
    NSLog(@"JRFFFormatContext release");
}

@end

//
//  JRFFTools.h
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/8.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avformat.h"

typedef NS_ENUM(NSUInteger, JRFFDecoderErrorCode) {
    JRFFDecoderErrorCodeFormatCreate,
    JRFFDecoderErrorCodeFormatOpenInput,
    JRFFDecoderErrorCodeFormatFindStreamInfo,
    JRFFDecoderErrorCodeStreamNotFound,
    JRFFDecoderErrorCodeCodecContextCreate,
    JRFFDecoderErrorCodeCodecContextSetParam,
    JRFFDecoderErrorCodeCodecFindDecoder,
    JRFFDecoderErrorCodeCodecVideoSendPacket,
    JRFFDecoderErrorCodeCodecAudioSendPacket,
    JRFFDecoderErrorCodeCodecVideoReceiveFrame,
    JRFFDecoderErrorCodeCodecAudioReceiveFrame,
    JRFFDecoderErrorCodeCodecOpen2,
    JRFFDecoderErrorCodeAuidoSwrInit,
};

@interface JRFFTools : NSObject

void JRFFLog(void *context, int level, const char *format, va_list args);

NSError * JRFFCheckError(int result);

NSError * JRFFCheckErrorCode(int result, NSUInteger errorCode);

NSDictionary * JRFFFoundationBrigeOfAVDictionary(AVDictionary * avDictionary);

AVDictionary * JRFFFFmpegBrigeOfNSDictionary(NSDictionary * dictionary);

double JRFFStreamGetTimebase(AVStream * stream, double default_timebase);

double JRFFStreamGetFPS(AVStream * stream, double timebase);

@end

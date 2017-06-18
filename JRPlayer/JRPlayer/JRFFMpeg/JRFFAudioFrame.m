//
//  JRFFAudioFrame.m
//  JRPlayer
//
//  Created by fanjianrong on 2017/6/16.
//  Copyright © 2017年 樊健荣. All rights reserved.
//

#import "JRFFAudioFrame.h"

@implementation JRFFAudioFrame

{
    size_t buffer_size;
}

- (JRFFFrameType)type
{
    return JRFFFrameTypeAudio;
}

- (int)size
{
    return (int)self->length;
}

- (void)setSamplesLength:(NSUInteger)samplesLength
{
    if (self->buffer_size < samplesLength) {
        if (self->buffer_size > 0 && self->samples != NULL) {
            free(self->samples);
        }
        self->buffer_size = samplesLength;
        self->samples = malloc(self->buffer_size);
    }
    self->length = (int)samplesLength;
    self->output_offset = 0;
}

- (void)dealloc
{
    if (self->buffer_size > 0 && self->samples != NULL) {
        free(samples);
    }
}

@end
